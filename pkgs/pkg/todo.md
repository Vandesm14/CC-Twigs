# Processes

## Installing Packages

### Fetching Packages (Pre-Install)

- [ ] User runs `pkg add <package>`
- [ ] Check if the package is already installed
- [ ] If so, get it's checksum
- [ ] Get mirrors from the mirrorlist
- [ ] Query the mirrors for the package
- [ ] Recurse for dependencies until we have a list of all packages to install
- [ ] Compare the checksums of all files/deps and filter the ones we need to install/update
- [ ] Report to the user the size, version, and other information (# files, deps, etc)
  - [ ] Include which are ignored, updated, and installed
- [ ] Confirm with the user that they want to install the package(s)

### Installing Packages

- [ ] We have a list of packages to install (package + deps), including every file and checksum
- [ ] Create a temporary directory to store the files
- [ ] Download all files to the temporary directory
- [ ] Verify the checksums of all files
- [ ] Move the files to their respective package folders (creating them if needed)
- [ ] Update the database with the new package information
- [ ] Remove the temporary directory
- [ ] Report to the user that the package(s) have been installed
