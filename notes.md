- gauge is in SectionOfLine -> SOLTrack
- gauge property is called "ILL_Gauging" and apparently we need to look it up in some other database, the value is numeric but the string is only in OptionalValue (which is optional)
- we have location from SectionOfLine -> SOLOPStart Value and SOLOPEnd Value
- those link to OperationalPoint -> UniqueOPID, which then has OPGeographicLocation with Latitude (+/-) string... and Longitude (+/-) string

-> job 1: extract operational points and geographic locations
-> job 2: extract SOLTrakcs, their gauges, their starts and ends
-> job 3: join
