## [1.0.6] - 2022-07-13
### Added
- Raw capacity and parity information to status report

### Changed
- Disk drive status to New-PfaStatusReport
 
## [1.0.5] - 2022-04-18
### Fixed
- Broken image link in Outlook for Health Chart

## [1.0.4] - 2022-04-13
### Added
- Health Chart

### Changed
- Health Chart to New-PfaStatusReport

### Fixed
- Removed PipelineVariable for 5.1 compatibility

## [1.0.3] - 2022-02-08
### Added
- Required assembly reference for System.Xml.Linq

## [1.0.2] - 2022-02-07
### Added
- Support for PurityOS 5.3.0 and newer
- Validation for Replication data
- UTC / LocalTime check on connection expiration
- UseBasicParsing for 5.1 compatibility

### Fixed
- Cycling of chart colors
- Minor issues with example scripts

### Removed
- DateTime conversion to LocalTime

## [1.0.1] - 2022-02-03
### Added
- Warning that chart generation isn't currently - supported on 5.3
- Get-PfaDiskUsage example script

### Changed
- Doctype for example scripts

### Fixed
- Get-Date doesn't support -AsUTC on 5.1

## [1.0.0] - 2022-02-02
- Initial Release
