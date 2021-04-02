## pass vera

A [`pass`](https://www.passwordstore.org/) extension that encrypts the entire password-sotre in an encrypted [`veracrypt`](https://sourceforge.net/projects/veracrypt/) drive.

### Description

The names of the files and directories used by `pass` are not encrypted, so one may wish to add another layer of security by putting these inside of a file that turns into an encrypted drive when it mounts to one's computer.

### TODO

+ Add a 'do-it-for-me' option
+ Add configuration file for veracrypt
+ Add option to create inner drive

This is based off of [`pass-tomb`](https://github.com/roddhjav/pass-tomb) but built to work with macOS instead.  It uses `launchctl` instead of `systemd` to create a timer to automatically close the drive.
