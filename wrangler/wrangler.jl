#!/bin/julia

using EzXML, Arrow, DataFrames, ThreadsX, CSV, JSON, QuackIO

headinsand(f, x) = begin
    x = skipmissing(x)
    isempty(x) && return missing
    f(x)
end
headinsand(f) = x -> headinsand(f, x) # or Base.Fix1(headinsand, f)

function extract_op_data(xml_file_path)
    op_ids = String[]
    lats = Float64[]
    lons = Float64[]
    approx_rows = 500_000
    sizehint!(op_ids, approx_rows)
    sizehint!(lats, approx_rows)
    sizehint!(lons, approx_rows)
    in_op = false
    current_op_id = ""
    current_lat = NaN
    current_lon = NaN
    reader = EzXML.StreamReader(open(xml_file_path))
    for typ in reader
        if typ == 1 # element
            name = nodename(reader)
            if endswith(name, "OperationalPoint")
                in_op = true
                current_op_id = ""
                current_lat = NaN
                current_lon = NaN
            elseif in_op
                if endswith(name, "UniqueOPID")
                    current_op_id = haskey(reader, "Value") ? reader["Value"] : ""
                elseif endswith(name, "OPGeographicLocation")
                    current_lat = haskey(reader, "Latitude") ? parse(Float64, reader["Latitude"]) : NaN
                    current_lon = haskey(reader, "Longitude") ? parse(Float64, reader["Longitude"]) : NaN
                end
            end
        elseif typ == 15 # closing tag
            if endswith(nodename(reader), "OperationalPoint")
                in_op = false
                push!(op_ids, current_op_id)
                push!(lats, current_lat)
                push!(lons, current_lon)
            end
        end
    end
    close(reader)
    df = DataFrame(UniqueOPID = op_ids, Latitude = lats, Longitude = lons)
end

function extract_sol_data(xml_file_path)
    solop_starts = String[]
    solop_ends = String[]
    track_names = String[]
    gauges = Array{Array{UInt16,1},1}()
    gauge_names = Array{Array{String,1},1}()
    approx_rows = 500_000
    sizehint!(solop_starts, approx_rows)
    sizehint!(solop_ends, approx_rows)
    sizehint!(gauges, approx_rows)
    sizehint!(gauge_names, approx_rows)
    in_op = false
    current_solop_start = ""
    current_solop_end = ""
    current_track_name = ""
    current_gauges = UInt16[]
    current_gauge_names = String[]
    sizehint!(current_gauges, 2)
    sizehint!(current_gauge_names, 2)
    current_node = :none
    reader = EzXML.StreamReader(open(xml_file_path))
    for typ in reader
        if typ == 1 # element
            name = nodename(reader)
            if endswith(name, "SectionOfLine")
                in_op = true
                current_node = :none
                current_solop_start = ""
                current_solop_end = ""
                current_track_name = ""
                current_gauges = UInt16[]
                current_gauge_names = String[]
                sizehint!(current_gauges, 2)
                sizehint!(current_gauge_names, 2)
            elseif in_op
                if endswith(name, "SOLOPStart")
                    current_solop_start = haskey(reader, "Value") ? reader["Value"] : ""
                elseif endswith(name, "SOLOPEnd")
                    current_solop_end = haskey(reader, "Value") ? reader["Value"] : ""
                elseif endswith(name, "SOLTrack")
                    current_node = :soltrack
                elseif endswith(name, "SOLTrackParameter") && current_node == :soltrack
                    if (haskey(reader, "ID") && reader["ID"] == "ILL_Gauging")
                        push!(current_gauges, (haskey(reader, "Value") && reader["Value"] != "") ? parse(UInt16, reader["Value"]) : 0)  # not sure 0 is correct for missing
                        push!(current_gauge_names, haskey(reader, "OptionalValue") ? reader["OptionalValue"] : "")
                    end
                elseif endswith(name, "SOLTrackIdentification") && current_node == :soltrack
                    current_track_name = haskey(reader, "Value") ? reader["Value"] : ""
                end
            end
        elseif typ == 15 # closing tag
            if endswith(nodename(reader), "SectionOfLine")
                in_op = false
                push!(solop_starts, current_solop_start)
                push!(solop_ends, current_solop_end)
                push!(gauges, current_gauges)
                push!(gauge_names, current_gauge_names)
                push!(track_names, current_track_name)
            elseif endswith(nodename(reader), "SOLTrack")
                current_node = :none
            end
        end
    end
    close(reader)
    df = DataFrame(SOLTrackIdentification = track_names, SOLOPStart = solop_starts, SOLOPEnd = solop_ends, Gauge = gauges, GaugeName = gauge_names)
end

df_template = DataFrame(SOLOPStart = String[], SOLOPEnd = String[], Gauge = UInt16[], latitude_start = Float64[], longitude_start = Float64[], latitude_end = Float64[], longitude_end = Float64[])
function get_df(xml_file_path)
    df = extract_op_data(xml_file_path)
    df2 = extract_sol_data(xml_file_path)
    fdf = flatten(df2[!, Not([:GaugeName, :SOLTrackIdentification])], :Gauge) # often id, name often useless
    # fdf = combine(groupby(fdf, :SOLTrackIdentification), :Gauge => minimum => :Gauge, :SOLOPStart, :SOLOPEnd) # don't do this :)
    leftjoin(leftjoin(fdf, df, on = :SOLOPStart => :UniqueOPID, renamecols = "" => (x -> lowercase(x)*"_start")), df, on = :SOLOPEnd => :UniqueOPID, renamecols = "" => (x -> lowercase(x)*"_end"))
end
# jdf.GaugesHuman = join.(jdf.GaugeName, ", ")

gauge_to_human = CSV.read("../gauge_labels.csv", DataFrame)
track_to_intltrain = CSV.read("../track_to_biggest_international_train.csv", DataFrame)
gauge_area = CSV.read("../gauge_areas.csv", DataFrame)

dropmissing!(track_to_intltrain)
xml_paths = "data/".*(readdir("data") |> x -> filter!(endswith(".xml"), x))
# out_df = (Arrow.Table("checkpoint.arrow") |> DataFrame)[:, Not([:gauge_label, :area])]
out_df = ThreadsX.mapreduce(get_df, vcat, xml_paths, init = df_template)
leftjoin!(out_df, gauge_to_human, on = :Gauge => :gauge_number)
dropmissing!(out_df) # drop the tracks without gauges
leftjoin!(out_df, gauge_area, on = :gauge_label => :gauge_name)
Arrow.write("checkpoint.arrow", out_df) # no point starting from scratch

df_intl = leftjoin(out_df, track_to_intltrain, on = :gauge_label => :the_track)
dropmissing!(df_intl)
consolidated = combine(groupby(df_intl, [:latitude_start, :longitude_start, :latitude_end, :longitude_end]), [:universality, :our_train] => ((u, l) -> l[argmin(u)]) => :gauge_label)
Arrow.write("out.arrow", consolidated)
# hmm, missing spanish stuff again?


# sidequest: add uk data. we need gauge_label, latitude_start, longitude_start, latitude_end, longitude_end
# and that's it
uk_df = read_parquet(DataFrame, "../uk/uk.parquet")
leftjoin!(uk_df, gauge_area, on = :gauge_label => :gauge_name)
mini_df = vcat(out_df[!, [:gauge_label, :latitude_start, :longitude_start, :latitude_end, :longitude_end, :area]], uk_df[!, [:gauge_label, :latitude_start, :longitude_start, :latitude_end, :longitude_end, :area]])
#
 
# loading gauge area map
# output for use with https://github.com/bovine3dom/H3-MON
using H3.API, Dates
mini_df.h3 = h3ToString.(latLngToCell.(LatLng.(deg2rad.(mini_df.latitude_start), deg2rad.(mini_df.longitude_start)), 5))
consolidated = combine(groupby(mini_df, :h3), :area => headinsand(maximum) => :area, :gauge_label => (x -> join(unique(x), ", ")) => :gauges)
gc_area = first(gauge_area[gauge_area.gauge_name .== "GC", :area])
consolidated.area_norm = round.(consolidated.area ./ gc_area, sigdigits = 3)

dropmissing!(consolidated)
tday = "2026-03-18"
# tday = today()
topic = "loading_gauge"
mkpath("out/$topic/")
write("""out/$topic/$tday.json""", JSON.json(Dict(
    "t" => "Maximum cross-sectional train area (loading gauge) area relative to GC",
#    "raw" => true,
    "c" => "ERA, Network Rail"
)))
rename!(consolidated, :h3 => :index, :area_norm => :value)
CSV.write("""out/$topic/$tday.csv""", consolidated[!, [:index, :value, :gauges]])


# extra credit:
#
# geojson output of actual lines
#
dropmissing!(mini_df) # W9PLUS missing for some reason
shrunk = combine(groupby(mini_df, [:latitude_start, :longitude_start, :latitude_end, :longitude_end]), [:gauge_label, :area] => ((u, l) -> u[argmax(l)]) => :gauge_label, :area => maximum => :area)
shrunk.area_m2 = 2 .* shrunk.area ./ (1000 * 1000) # we only have half the area


function find_continuous_lines(segments::Vector{Tuple{Tuple{Float64, Float64}, Tuple{Float64, Float64}}})
    adj = Dict{Tuple{Float64, Float64}, Vector{Tuple{Tuple{Float64, Float64}, Int}}}()
    for (i, (p1, p2)) in enumerate(segments)
        push!(get!(adj, p1, []), (p2, i))
        push!(get!(adj, p2, []), (p1, i))
    end
    
    num_edges = length(segments)
    used_edges = falses(num_edges)
    all_paths = Vector{Vector{Vector{Float64}}}() 

    function traverse(start_node)
        path = [Float64[start_node[1], start_node[2]]]
        curr = start_node
        while true
            neighbors = get(adj, curr, [])
            idx = findfirst(x -> !used_edges[x[2]], neighbors)
            idx === nothing && break
            
            nxt_node, edge_idx = neighbors[idx]
            used_edges[edge_idx] = true
            push!(path, Float64[nxt_node[1], nxt_node[2]])
            curr = nxt_node
        end
        return path
    end

    for (node, neighbors) in adj
        if isodd(length(neighbors))
            while (idx = findfirst(x -> !used_edges[x[2]], neighbors)) !== nothing
                push!(all_paths, traverse(node))
            end
        end
    end

    for (node, neighbors) in adj
        while (idx = findfirst(x -> !used_edges[x[2]], neighbors)) !== nothing
            push!(all_paths, traverse(node))
        end
    end

    return all_paths
end

function process_to_geojson(df)
    features = []
    gauge_groups = groupby(df, :gauge_label)

    for group in gauge_groups
        label = first(group.gauge_label)
        area_val = first(group.area_m2) 
        segments = map(eachrow(group)) do row
            ((row.longitude_start, row.latitude_start), 
             (row.longitude_end, row.latitude_end))
        end
        continuous_paths = find_continuous_lines(segments)
        for path in continuous_paths
            push!(features, Dict(
                "type" => "Feature",
                "geometry" => Dict(
                    "type" => "LineString",
                    "coordinates" => simplify(path, 0.001)  
                ),
                "properties" => Dict(
                    "gauge_label" => label,
                    "value" => area_val,
                    "weight" => path_len(path)
                )
            ))
        end
    end
    return Dict("type" => "FeatureCollection", "features" => features)
end

function get_sq_dist(p1, p2)
    dx = p1[1] - p2[1]
    dy = p1[2] - p2[2]
    return dx * dx + dy * dy
end

function path_len(path)
    l = 0.0
    for i in 1:(length(path) - 1)
        l += get_sq_dist(path[i], path[i + 1])
    end
    return l
end

function get_sq_seg_dist(p, p1, p2)
    x, y = p1[1], p1[2]
    dx = p2[1] - x
    dy = p2[2] - y

    if dx != 0 || dy != 0
        t = ((p[1] - x) * dx + (p[2] - y) * dy) / (dx * dx + dy * dy)
        if t > 1
            x, y = p2[1], p2[2]
        elseif t > 0
            x += dx * t
            y += dy * t
        end
    end

    dx = p[1] - x
    dy = p[2] - y
    return dx * dx + dy * dy
end

function simplify_radial_dist(points, sq_tolerance)
    prev_point = points[1]
    new_points = [prev_point]
    point = prev_point

    for i in 2:length(points)
        point = points[i]
        if get_sq_dist(point, prev_point) > sq_tolerance
            push!(new_points, point)
            prev_point = point
        end
    end

    if prev_point !== point
        push!(new_points, point)
    end
    return new_points
end

function simplify_dp_step!(points, first_idx, last_idx, sq_tolerance, simplified)
    max_sq_dist = sq_tolerance
    index = 0

    for i in (first_idx + 1):(last_idx - 1)
        sq_dist = get_sq_seg_dist(points[i], points[first_idx], points[last_idx])
        if sq_dist > max_sq_dist
            index = i
            max_sq_dist = sq_dist
        end
    end

    if max_sq_dist > sq_tolerance
        if (index - first_idx) > 1
            simplify_dp_step!(points, first_idx, index, sq_tolerance, simplified)
        end
        push!(simplified, points[index])
        if (last_idx - index) > 1
            simplify_dp_step!(points, index, last_idx, sq_tolerance, simplified)
        end
    end
end

# adapted from simplify-js
function simplify(points, tolerance=0.0001, highest_quality=false)
    n = length(points)
    n <= 2 && return points
    sq_tolerance = tolerance * tolerance
    pts = highest_quality ? points : simplify_radial_dist(points, sq_tolerance)
    
    # Ramer-Douglas-Peucker simplification
    last_idx = length(pts)
    simplified = [pts[1]]
    simplify_dp_step!(pts, 1, last_idx, sq_tolerance, simplified)
    push!(simplified, pts[last_idx])
    return simplified
end

geojson_output = process_to_geojson(shrunk)

JSON.json("loading_gauges.geojson", geojson_output)
