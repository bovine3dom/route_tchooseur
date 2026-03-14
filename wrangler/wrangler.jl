#!/bin/julia

using EzXML, Arrow, DataFrames

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

df = extract_op_data("data/20260310_RINF_RFI.xml")
df2 = extract_sol_data("data/20260310_RINF_RFI.xml")
fdf = flatten(df2, [:Gauge, :GaugeName])
# fdf = combine(groupby(fdf, :SOLTrackIdentification), :Gauge => minimum => :Gauge, :SOLOPStart, :SOLOPEnd) # don't do this :)
jdf = leftjoin(leftjoin(fdf, df, on = :SOLOPStart => :UniqueOPID, renamecols = "" => (x -> lowercase(x)*"_start")), df, on = :SOLOPEnd => :UniqueOPID, renamecols = "" => (x -> lowercase(x)*"_end"))
# jdf.GaugesHuman = join.(jdf.GaugeName, ", ")
Arrow.write("out.arrow", jdf)


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
