## pass vera

A [`pass`](https://www.passwordstore.org/) extension that encrypts the entire password-sotre in an encrypted [`veracrypt`](https://sourceforge.net/projects/veracrypt/) drive.

### Description

The file and directory names in the password-store that is created by `pass` are not encrypted and are available for anyone with access to the computer to see. `pass vera` provides a solution to this problem by moving the password-store to an encrypted drive created by `veracrypt`. The password-store can be encrypted (i.e., the folder doesn't exist) when it is not being used.

The same GPG key (by default) is used to encrypt passwords and the veracrypt drive, therefore one doesn't need to manage another key. There is also an option to move an existing password-store to the location of the new one without any manual intervention. Moreover,  pass-vera can be given a timer as an argument that will automatically close the password-store after the specified amount of time has passed

### Before Using this Program

Make a backup of your password-store directory. Do this even if you plan on specifying the `--for-me` argument which will transfer over the pre-existing password-store for you.  Once the vera is created and the passwords are moved into the vera, only then should you delete the backup.

### Workflow

1. Create a password vera with `pass vera <gpg-id>`. Type anything in the text file that opens (make sure to remember it). Then, one will be prompted for a password to be entered for the veracrypt drive itself (it does not have to be the same as the text file). The "vera", is created and mounted in `PASSWORD_STORE_DIR` (or, if unset, then `~/.password-store`). Finally, the newly created drive will be initialized as a password-store using the same GPG key.

The text file created in this process is used as a keyfile to the vera. It works by encrypting the key using GPG when it is not being used, and decrypting the key at the time of mounting the drive/using `pass open`.

2. If you have `PASSWORD_STORE_DIR` set, copy your backup of the password-store to this location, otherwise copy it to `~/.password-store` (wherever `pass vera` is mounted). Now, pass can be used as usual.

3. When finished, close the password vera: `pass close`

4. To use `pass` again, open the password vera: `pass open`

### Usage

```
pass vera 1.0 - A pass extension that adds another layer of encryption
                by encrypting the password-store inside a veracrypt drive.

  Usage:
    pass vera <gpg-id> [-n] [-t time] [-f] [-p subfolder] [-c] [-s]
                        [-i | -k | --tmp-key] [--for-me] [-r] [-o]
        Create and initialize a new password vera
        Use gpg-id for encryption of both vera and passwords

    pass open [subfolder] [-i] [-c] [-t time] [-f]
        Open a password vera

    pass close [store]
        Close a password vera

  Options:
    -n, --no-init        Do not initialize the password store
    -t, --timer          Close the store after a given time
    -p, --path           Create the store for that specific subfolder
    -c, --truecrypt      Enable compatibility with truecrypt
    -k, --vera-key       Create a key with veracrypt instead of GPG
    -o, --overwrite-key  Overwrite existing key
    -i, --invisi-key     Create a key that doesn't exist when it's not being used
        --tmp-key        Generate a one time temporary key
        --for-me         Copy existing password-store to new one when creating vera
    -r, --reencrypt      Reencrypt passwords when creating to new vera (use with --for-me)
    -f, --force          Force operation (i.e. even if mounted volume is active)
    -s, --status         Show status of pass vera (open or closed)
    -q, --quiet          Be quiet
    -v, --verbose        Be verbose
    -d, --debug          Debug the launchctl agent with a stderr file located in $HOME folder
        --unsafe         Speed up vera creation (for testing only)
    -V, --version        Show version information.
    -h, --help           Print this help message and exit.

More information may be found in the pass-vera(1) man page.
```

To view more information, `man pass-vera`.

### Examples

#### Create a new password vera

```
zx2c4@laptop ~ $ pass vera Jason@zx2c4.com
 (*) GPG key created

  Enter password: ****************
  Re-enter password: ****************
  Done: 100.000%  Speed: 6.4 MiB/s  Left: 0 s
  The VeraCrypt volume has been successfully created.

  Enter password for ~/.password.vera: ****************
 (*) Your password vera has been created and opened in ~/.password-store.
 (*) password-store initialized for Jason@zx2c4.com.
  .  Your vera is: ~/.password.vera
  .  Your vera key is: ~/.password.key.vera
  .  You can now use pass as usual.
  .  When finished, close the password vera using 'pass close'.
```

#### Open a password vera

```
zx2c4@laptop ~ $ pass open
  Enter password for ~/.password.vera: ****************
 (*) Your password vera has been opened in ~/.password-store.
  .  You can now use pass as usual.
  .  When finished, close the password vera using 'pass close'.
```

#### Close a password vera

```
zx2c4@laptop ~ $ pass close
 (*) Your password vera has been closed.
  .  Your passwords remain present in ~/.password.vera.
```

#### Create a new password vera and set a timer

```
zx2c4@laptop ~ $ pass vera Jason@zx2c4.com --timer="1 hour"
 (*) GPG key created

  Enter password: ****************
  Re-enter password: ****************
  Done: 100.000%  Speed: 6.4 MiB/s  Left: 0 s
  The VeraCrypt volume has been successfully created.

  Enter password for ~/.password-store: ****************
 (*) pass-close.password.vera.plist loaded
 (*) Your password vera has been created and opened in ~/.password-store.
 (*) password-store initialized for Jason@zx2c4.com.
  .  Your vera is: ~/.password.vera
  .  Your vera key is: ~/.password.key.vera
  .  You can now use pass as usual.
  .  This password-store will be closed in: 1 hour
```

**NOTE [1]:** Timer format must match one of the following:
    1. "1 hour 5 minutes"
    2. "1hour 5minutes"
    3. "1hr 5 minutes"
    4. "1 hr 5 mins"
    5. "1hr 5mins"
    6. 1hr

- An hour is not required when specifying time. Also, if both an hour and minute are specified, place the parameter in quotation marks. The only reason why one would not ever quote the parameter is if something like 1hr is given.

**NOTE [2]:** The `launchctl` agent is rounded to the nearest minute and may not close in the exact amount of specified  time.  For  example,  the  time  is `10:02:20` and a `1 minute` timer is given, the `launchctl` agent will run in `40 seconds`.


#### Open a password vera, set a timer, and add additional time after 5 minutes have passed

```
zx2c4@laptop ~ $ pass open --timer="10 minutes"
  Enter password for ~/.password.vera: ****************
 (*) pass-close.password.vera.plist loaded
 (*) Your password vera has been opened in ~/.password-store.
  .  You can now use pass as usual.
  .  This password-store will be closed in: 10 minutes

zx2c4@laptop ~ $ pass open --timer="10 minutes"
  w  The veracrypt drive is already mounted, not opening
 (*) pass-close.password.vera.plist timer has been updated
 (*) Your password vera has been opened in ~/.password-store.
  .  You can now use pass as usual.
  .  This password-store will be closed in: 15 minutes
```

#### Create a password vera using an 'invisible key' & copy an existing password-store (`$PASSWORD_STORE_DIR`)

```
zx2c4@laptop ~ $ pass vera Jason@zx2c4.com --for-me --invisi-key
 (*) Invisible key created
  Automatically transferring password stores:
		  [ /Users/Jason/.password-store/ ]

  Enter password: ****************
  Re-enter password: ****************
  Done: 100.000%  Speed: 6.1 MiB/s  Left: 0 s
  The VeraCrypt volume has been successfully created.

  Enter password for ~/.password.vera: ****************
 (*) Your password vera has been created and opened in ~/password-store.
 (*) Password store initialized for Jason@zx2c4.com
  .  Your vera is: ~/.password.vera
  .  Your vera key is: /var/~/dl7rz8zgn/T//pass.H9qIkMm/.invisi.key
  .  You can now use pass as usual.
  .  When finished, close the password vera using 'pass close'.
```

### Environmental Variables

- `PASSWORD_STORE_VERA`: Path to `veracrypt` executable
- `PASSWORD_STORE_VERA_FILE`: Path to the password vera, by default `~/.password.vera`
- `PASSWORD_STORE_VERA_KEY`: Path to the password vera key file by default `~/.password.key.vera`
- `PASSWORD_STORE_VERA_SIZE`: Password vera size in MB, by default `10`

### Installation

**Requirements (minimal versions)**:
    - `pass 1.7.3`
    - `veracrypt 1.24-Update8`
        - `osxfuse` is a requirement for `veracrypt`
    - `launchd 7.0.0`

#### Homebrew

```sh
brew tap lmburns/pass-vera
brew install pass-vera

# or

brew install lmburns/pass-vera
```

#### Manual

```sh
git clone https://github.com/lmburns/pass-vera
cd pass-vera
make install
```

### Import Existing `password-store`

#### Option 1

1. `mv ~/.password-store ~/.password-store-bkp`
2. `pass vera <gpg-id>`
3. `mv ~/.password-store-bkp ~/.password-store`

#### Option 2

1. `cp -r ~/.password-store ~/.password-store-bkp`
2. `pass vera <gpg-id> --for-me`
    - `--reencrypt` Can be added if one would like to re-encrypt the passwords when moving them
3. Check to make sure it copied correctly
4. `rm -rf ~/.password-store-bkp`

### TODO

- [x] ~~Add a 'do-it-for-me' option~~
- [x] ~~Create a homebrew package~~
- [ ] Add configuration file for veracrypt
- [ ] Add option to create inner drive

### Feedback / Contribution

Any and all is welcomed.

### Inspiration, Miscellaneous

- This is heavily based off of [`pass-tomb`](https://github.com/roddhjav/pass-tomb). Some pieces of code were taken from it and it provided an outline for me to do this project. This `README` is also structured in a very similar way. `pass-vera` was designed to work with macOS, since macOS doesn't support [dm-crypt](https://wiki.archlinux.org/index.php/dm-crypt) encryption, which is what `pass-tomb` uses. `pass-vera` also uses `launchctl` instead of `systemd` to create the timer that will automatically close/dismount the password-store.
- [`MacTomb`](https://github.com/davinerd/MacTomb/blob/master/README.md) is available, which creates an encrypted DMG and stores files (built for applications) within it. It would be interesting to fork this project and create the same thing that I have created.

### License

```
Copyright (C) 2021 Lucas Burns

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
```
