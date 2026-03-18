#!/bin/julia

using EzXML, Arrow, DataFrames, ThreadsX, CSV, JSON

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


# loading gauge area map
# output for use with https://github.com/bovine3dom/H3-MON
using H3.API, Dates
out_df.h3 = h3ToString.(latLngToCell.(LatLng.(deg2rad.(out_df.latitude_start), deg2rad.(out_df.longitude_start)), 5))
consolidated = combine(groupby(out_df, :h3), :area => headinsand(maximum) => :area, :gauge_label => (x -> join(unique(x), ", ")) => :gauges)
gc_area = first(gauge_area[gauge_area.gauge_name .== "GC", :area])
consolidated.area_norm = round.(consolidated.area ./ gc_area, sigdigits = 3)

dropmissing!(consolidated)
tday = today()
topic = "loading_gauge"
mkpath("out/$topic/")
write("""out/$topic/$tday.json""", JSON.json(Dict(
    "t" => "Maximum cross-sectional train area (loading gauge) area relative to GC",
#    "raw" => true,
    "c" => "ERA"
)))
rename!(consolidated, :h3 => :index, :area_norm => :value)
CSV.write("""out/$topic/$tday.csv""", consolidated[!, [:index, :value]])


# -- duckdb
# INSTALL webbed FROM community;
# LOAD webbed;

# SELECT UniqueOPID, OPGeographicLocation FROM read_xml(
#     'data/20260310_RINF_RFI.xml',
#     maximum_file_size = 2147483648,
#     record_element = 'OperationalPoint'
# )
# --WHERE OPGeographicLocation IS NOT NULL
# LIMIT 1;
