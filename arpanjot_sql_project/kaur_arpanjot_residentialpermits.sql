<<<<<<< HEAD
-- Create analytics database
CREATE DATABASE seattle_analytics;
-- Select database
USE seattle_analytics;

-- 1. Create Location Dimension Table
CREATE TABLE LocationDim (
    LocationID INT AUTO_INCREMENT PRIMARY KEY,
    ProjectAddress VARCHAR(255),
    Neighborhood VARCHAR(100),
    CommunityReportingArea VARCHAR(100),
    CommunityReportingAreaNumber DECIMAL(5,2),
    CouncilDistrict INT,
    UrbanVillageName VARCHAR(100),
    UrbanVillageType VARCHAR(100),
    Longitude DECIMAL(10,7),
    Latitude DECIMAL(10,7)
);
-- Populate Location dimension
INSERT INTO LocationDim(
    ProjectAddress, Neighborhood, CommunityReportingArea,
    CommunityReportingAreaNumber, CouncilDistrict,
    UrbanVillageName, UrbanVillageType, Longitude, Latitude
)
SELECT DISTINCT
    project_address,
    neighborhood,
    community_reporting_area,
    community_reporting_area_number,
    council_district,
    urban_village_name,
    urban_village_type,
    longitude,
    latitude
FROM permit_staging;

-- 2. Create Zoning Dimension Table
CREATE TABLE ZoningDim(
	ZoningID INT AUTO_INCREMENT PRIMARY KEY,
	ZoningPrimaryZone VARCHAR(50),
    ZoningCategory VARCHAR(50),
    ZoningClassification VARCHAR(50),
    ZoningAllZones VARCHAR(100),
    ZoningReportedZone VARCHAR(50),
    UNIQUE (ZoningPrimaryZone, ZoningReportedZone)
);
-- Populate Zoning dimension
INSERT INTO ZoningDim(
	ZoningPrimaryZone, ZoningCategory, ZoningClassification,
    ZoningAllZones, ZoningReportedZone
)
SELECT DISTINCT
    zoning_primary_zone,
    zoning_category,
    zoning_classification,
    zoning_all_zones,
    zoning_reported_zone
FROM permit_staging;

-- 3. Create Permit Type Dimension Table
CREATE TABLE PermitTypeDim (
    PermitTypeID INT AUTO_INCREMENT PRIMARY KEY,
    PermitStage VARCHAR(50),
    TypeOfPermit VARCHAR(100),
    Source VARCHAR(50)
);
-- Populate Permit Type dimension
INSERT INTO PermitTypeDim (PermitStage, TypeOfPermit, Source)
SELECT DISTINCT
    permit_stage,
    type_of_permit,
    source
FROM permit_staging;

-- 4. Dwelling Unit Dimension
CREATE TABLE DwellingUnitDim (
    DwellingUnitID INT AUTO_INCREMENT PRIMARY KEY,
    DwellingUnitType VARCHAR(100),
    DwellingUnitTypeCode VARCHAR(50),
    CondoParcelOrPlat CHAR(1)
);
-- Populate DwellingUnitDim
INSERT IGNORE INTO DwellingUnitDim(
    DwellingUnitType, DwellingUnitTypeCode, CondoParcelOrPlat
)
SELECT DISTINCT
	dwelling_unit_type,
    dwelling_unit_type_code,
    condo_parcel_or_plat
FROM permit_staging;

-- 5. Create Permit Dates Dimension Table
CREATE TABLE PermitDates (
    PermitNumber BIGINT PRIMARY KEY,
    ApplicationDate DATE,
    IssuedDate DATE,
    FinalDate DATE,
    IssuedQuarter INT,
    FinalQuarter INT
);
-- Populate Permit Dates table
INSERT INTO PermitDates (
	PermitNumber, ApplicationDate, IssuedDate, FinalDate,
    IssuedQuarter, FinalQuarter
)
SELECT 
    permit_number,
    application_date,
    permit_issued_date,
    permit_final_date,
    quarter_issued,
    quarter_final
FROM permit_staging;

-- 6. Create Fact Table: Permits
CREATE TABLE FactPermits (
    PermitNumber BIGINT PRIMARY KEY,
    LocationID INT,
    ZoningID INT,
    DwellingUnitID INT,
    PermitTypeID INT,
    NewUnitsPermitted INT,
    DemolishedUnitsPermitted INT,
    NetUnitsPermitted INT,
    FOREIGN KEY (PermitNumber) REFERENCES PermitDates(PermitNumber),
    FOREIGN KEY (LocationID) REFERENCES LocationDim(LocationID),
    FOREIGN KEY (ZoningID) REFERENCES ZoningDim(ZoningID),
    FOREIGN KEY (DwellingUnitID) REFERENCES DwellingUnitDim(DwellingUnitID),
    FOREIGN KEY (PermitTypeID) REFERENCES PermitTypeDim(PermitTypeID)
);
-- Populate Fact table by joining staging data to dimensions
INSERT IGNORE INTO FactPermits (
    PermitNumber,
    LocationID,
    ZoningID,
    DwellingUnitID,
    PermitTypeID,
    NewUnitsPermitted,
    DemolishedUnitsPermitted,
    NetUnitsPermitted
)
SELECT 
    ps.permit_number,
    l.LocationID,
    z.ZoningID,
    d.DwellingUnitID,
    t.PermitTypeID,
    ps.new_units_permitted,
    ps.demolished_units_permitted,
    ps.net_units_permitted
FROM permit_staging ps
JOIN LocationDim l ON ps.project_address = l.ProjectAddress
JOIN ZoningDim z ON ps.zoning_primary_zone = z.ZoningPrimaryZone
    AND ps.zoning_reported_zone = z.ZoningReportedZone
JOIN DwellingUnitDim d ON ps.dwelling_unit_type = d.DwellingUnitType
    AND ps.dwelling_unit_type_code = d.DwellingUnitTypeCode
JOIN PermitTypeDim t ON ps.permit_stage = t.PermitStage
    AND ps.type_of_permit = t.TypeOfPermit;

-- ANALYTICAL QUERIES
-- 1. Which neighborhoods are adding the most new housing units within each zoning type?
SELECT *
FROM (
    SELECT 
        l.Neighborhood,
        d.DwellingUnitType,
        SUM(f.NewUnitsPermitted) AS TotalNewUnits,
        RANK() OVER (PARTITION BY d.DwellingUnitType ORDER BY SUM(f.NewUnitsPermitted) DESC) AS RankByType
    FROM FactPermits f
    JOIN DwellingUnitDim d ON f.DwellingUnitID = d.DwellingUnitID
    JOIN LocationDim l ON f.LocationID = l.LocationID
    GROUP BY l.Neighborhood, d.DwellingUnitType
) AS ranked
WHERE RankByType <= 3
ORDER BY DwellingUnitType, RankByType;

-- 2. Which neighborhoods in Seattle saw the most commercial 
-- development between 2023 and 2025, based on new commercial units permitted?
SELECT 
    l.Neighborhood,
    SUM(f.NewUnitsPermitted) AS TotalUnits,
    COUNT(f.PermitNumber) AS TotalPermits
FROM FactPermits f
JOIN LocationDim l ON f.LocationID = l.LocationID
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
JOIN PermitDates pd ON f.PermitNumber = pd.PermitNumber
WHERE z.ZoningClassification LIKE "c"   -- "c" for commercial zoning
  AND YEAR(pd.IssuedDate) BETWEEN 2023 AND 2025
GROUP BY l.Neighborhood
ORDER BY TotalUnits DESC, TotalPermits DESC;

-- 3. What is the distribution of new housing units by dwelling type (e.g., SF, MF, ADU) 
-- across different zoning classifications (e.g., NR1, LR1, MR-85)?
SELECT 
    z.ZoningClassification,
    d.DwellingUnitType,
    SUM(f.NewUnitsPermitted) AS TotalNewUnits
FROM FactPermits f
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
JOIN DwellingUnitDim d ON f.DwellingUnitID = d.DwellingUnitID
GROUP BY z.ZoningClassification, d.DwellingUnitType
ORDER BY z.ZoningClassification, TotalNewUnits DESC;

-- 4. Which zoning classifications have the highest number of demolitions, 
-- and how does this correlate with new units permitted in the same areas?
SELECT 
    z.ZoningClassification,
    SUM(f.DemolishedUnitsPermitted) AS TotalDemolitions,
    SUM(f.NewUnitsPermitted) AS TotalNewUnits
FROM FactPermits f
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
GROUP BY z.ZoningClassification
HAVING TotalDemolitions > 0
ORDER BY TotalDemolitions DESC, TotalNewUnits DESC;


=======
-- Create analytics database
CREATE DATABASE seattle_analytics;
-- Select database
USE seattle_analytics;

-- 1. Create Location Dimension Table
CREATE TABLE LocationDim (
    LocationID INT AUTO_INCREMENT PRIMARY KEY,
    ProjectAddress VARCHAR(255),
    Neighborhood VARCHAR(100),
    CommunityReportingArea VARCHAR(100),
    CommunityReportingAreaNumber DECIMAL(5,2),
    CouncilDistrict INT,
    UrbanVillageName VARCHAR(100),
    UrbanVillageType VARCHAR(100),
    Longitude DECIMAL(10,7),
    Latitude DECIMAL(10,7)
);
-- Populate Location dimension
INSERT INTO LocationDim(
    ProjectAddress, Neighborhood, CommunityReportingArea,
    CommunityReportingAreaNumber, CouncilDistrict,
    UrbanVillageName, UrbanVillageType, Longitude, Latitude
)
SELECT DISTINCT
    project_address,
    neighborhood,
    community_reporting_area,
    community_reporting_area_number,
    council_district,
    urban_village_name,
    urban_village_type,
    longitude,
    latitude
FROM permit_staging;

-- 2. Create Zoning Dimension Table
CREATE TABLE ZoningDim(
	ZoningID INT AUTO_INCREMENT PRIMARY KEY,
	ZoningPrimaryZone VARCHAR(50),
    ZoningCategory VARCHAR(50),
    ZoningClassification VARCHAR(50),
    ZoningAllZones VARCHAR(100),
    ZoningReportedZone VARCHAR(50),
    UNIQUE (ZoningPrimaryZone, ZoningReportedZone)
);
-- Populate Zoning dimension
INSERT INTO ZoningDim(
	ZoningPrimaryZone, ZoningCategory, ZoningClassification,
    ZoningAllZones, ZoningReportedZone
)
SELECT DISTINCT
    zoning_primary_zone,
    zoning_category,
    zoning_classification,
    zoning_all_zones,
    zoning_reported_zone
FROM permit_staging;

-- 3. Create Permit Type Dimension Table
CREATE TABLE PermitTypeDim (
    PermitTypeID INT AUTO_INCREMENT PRIMARY KEY,
    PermitStage VARCHAR(50),
    TypeOfPermit VARCHAR(100),
    Source VARCHAR(50)
);
-- Populate Permit Type dimension
INSERT INTO PermitTypeDim (PermitStage, TypeOfPermit, Source)
SELECT DISTINCT
    permit_stage,
    type_of_permit,
    source
FROM permit_staging;

-- 4. Dwelling Unit Dimension
CREATE TABLE DwellingUnitDim (
    DwellingUnitID INT AUTO_INCREMENT PRIMARY KEY,
    DwellingUnitType VARCHAR(100),
    DwellingUnitTypeCode VARCHAR(50),
    CondoParcelOrPlat CHAR(1)
);
-- Populate DwellingUnitDim
INSERT IGNORE INTO DwellingUnitDim(
    DwellingUnitType, DwellingUnitTypeCode, CondoParcelOrPlat
)
SELECT DISTINCT
	dwelling_unit_type,
    dwelling_unit_type_code,
    condo_parcel_or_plat
FROM permit_staging;

-- 5. Create Permit Dates Dimension Table
CREATE TABLE PermitDates (
    PermitNumber BIGINT PRIMARY KEY,
    ApplicationDate DATE,
    IssuedDate DATE,
    FinalDate DATE,
    IssuedQuarter INT,
    FinalQuarter INT
);
-- Populate Permit Dates table
INSERT INTO PermitDates (
	PermitNumber, ApplicationDate, IssuedDate, FinalDate,
    IssuedQuarter, FinalQuarter
)
SELECT 
    permit_number,
    application_date,
    permit_issued_date,
    permit_final_date,
    quarter_issued,
    quarter_final
FROM permit_staging;

-- 6. Create Fact Table: Permits
CREATE TABLE FactPermits (
    PermitNumber BIGINT PRIMARY KEY,
    LocationID INT,
    ZoningID INT,
    DwellingUnitID INT,
    PermitTypeID INT,
    NewUnitsPermitted INT,
    DemolishedUnitsPermitted INT,
    NetUnitsPermitted INT,
    FOREIGN KEY (PermitNumber) REFERENCES PermitDates(PermitNumber),
    FOREIGN KEY (LocationID) REFERENCES LocationDim(LocationID),
    FOREIGN KEY (ZoningID) REFERENCES ZoningDim(ZoningID),
    FOREIGN KEY (DwellingUnitID) REFERENCES DwellingUnitDim(DwellingUnitID),
    FOREIGN KEY (PermitTypeID) REFERENCES PermitTypeDim(PermitTypeID)
);
-- Populate Fact table by joining staging data to dimensions
INSERT IGNORE INTO FactPermits (
    PermitNumber,
    LocationID,
    ZoningID,
    DwellingUnitID,
    PermitTypeID,
    NewUnitsPermitted,
    DemolishedUnitsPermitted,
    NetUnitsPermitted
)
SELECT 
    ps.permit_number,
    l.LocationID,
    z.ZoningID,
    d.DwellingUnitID,
    t.PermitTypeID,
    ps.new_units_permitted,
    ps.demolished_units_permitted,
    ps.net_units_permitted
FROM permit_staging ps
JOIN LocationDim l ON ps.project_address = l.ProjectAddress
JOIN ZoningDim z ON ps.zoning_primary_zone = z.ZoningPrimaryZone
    AND ps.zoning_reported_zone = z.ZoningReportedZone
JOIN DwellingUnitDim d ON ps.dwelling_unit_type = d.DwellingUnitType
    AND ps.dwelling_unit_type_code = d.DwellingUnitTypeCode
JOIN PermitTypeDim t ON ps.permit_stage = t.PermitStage
    AND ps.type_of_permit = t.TypeOfPermit;

-- ANALYTICAL QUERIES
-- 1. Which neighborhoods are adding the most new housing units within each zoning type?
SELECT *
FROM (
    SELECT 
        l.Neighborhood,
        d.DwellingUnitType,
        SUM(f.NewUnitsPermitted) AS TotalNewUnits,
        RANK() OVER (PARTITION BY d.DwellingUnitType ORDER BY SUM(f.NewUnitsPermitted) DESC) AS RankByType
    FROM FactPermits f
    JOIN DwellingUnitDim d ON f.DwellingUnitID = d.DwellingUnitID
    JOIN LocationDim l ON f.LocationID = l.LocationID
    GROUP BY l.Neighborhood, d.DwellingUnitType
) AS ranked
WHERE RankByType <= 3
ORDER BY DwellingUnitType, RankByType;

-- 2. Which neighborhoods in Seattle saw the most commercial 
-- development between 2023 and 2025, based on new commercial units permitted?
SELECT 
    l.Neighborhood,
    SUM(f.NewUnitsPermitted) AS TotalUnits,
    COUNT(f.PermitNumber) AS TotalPermits
FROM FactPermits f
JOIN LocationDim l ON f.LocationID = l.LocationID
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
JOIN PermitDates pd ON f.PermitNumber = pd.PermitNumber
WHERE z.ZoningClassification LIKE "c"   -- "c" for commercial zoning
  AND YEAR(pd.IssuedDate) BETWEEN 2023 AND 2025
GROUP BY l.Neighborhood
ORDER BY TotalUnits DESC, TotalPermits DESC;

-- 3. What is the distribution of new housing units by dwelling type (e.g., SF, MF, ADU) 
-- across different zoning classifications (e.g., NR1, LR1, MR-85)?
SELECT 
    z.ZoningClassification,
    d.DwellingUnitType,
    SUM(f.NewUnitsPermitted) AS TotalNewUnits
FROM FactPermits f
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
JOIN DwellingUnitDim d ON f.DwellingUnitID = d.DwellingUnitID
GROUP BY z.ZoningClassification, d.DwellingUnitType
ORDER BY z.ZoningClassification, TotalNewUnits DESC;

-- 4. Which zoning classifications have the highest number of demolitions, 
-- and how does this correlate with new units permitted in the same areas?
SELECT 
    z.ZoningClassification,
    SUM(f.DemolishedUnitsPermitted) AS TotalDemolitions,
    SUM(f.NewUnitsPermitted) AS TotalNewUnits
FROM FactPermits f
JOIN ZoningDim z ON f.ZoningID = z.ZoningID
GROUP BY z.ZoningClassification
HAVING TotalDemolitions > 0
ORDER BY TotalDemolitions DESC, TotalNewUnits DESC;


>>>>>>> 57426dc (move file)
