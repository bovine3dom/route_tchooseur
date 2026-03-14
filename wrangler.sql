-- duckdb
INSTALL webbed FROM community;
LOAD webbed;

SELECT UniqueOPID, OPGeographicLocation FROM read_xml(
    'data/20260310_RINF_RFI.xml',
    maximum_file_size = 2147483648,
    record_element = 'OperationalPoint'
)
--WHERE OPGeographicLocation IS NOT NULL
LIMIT 1;
