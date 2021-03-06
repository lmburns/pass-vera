## pass vera

A [`pass`](https://www.passwordstore.org/) extension that encrypts the entire password-store in a [`veracrypt`](https://sourceforge.net/projects/veracrypt/) drive.

### Description

The file and directory names in the password-store that is created by `pass` are not encrypted and are available for anyone with access to the computer to see. `pass vera` provides a solution to this problem by moving the password-store to an encrypted drive created by `veracrypt`. The password-store can be encrypted (i.e., the folder doesn't exist) when it is not being used.

The same GPG key (by default) is used to encrypt passwords and the veracrypt container, therefore one doesn't need to manage another key. There is also an option to move an existing password-store to the location of the new one without any manual intervention. Moreover,  pass-vera can be given a timer as an argument that will automatically close the password-store after the specified amount of time has passed

### Before Using this Program

Make a backup of your password-store directory. Do this even if you plan on specifying the `--for-me` argument which will transfer over the pre-existing password-store for you.  Once the vera is created and the passwords are moved into the vera, only then should you delete the backup.

---
### Workflow

1. Create a password vera with `pass vera <gpg-id>`. Type anything in the text file that opens (make sure to remember it). Then, one will be prompted for a password to be entered for the veracrypt drive itself (it does not have to be the same as the text file). The "vera", is created and mounted in `PASSWORD_STORE_DIR` (or, if unset, then `~/.password-store`). Finally, the newly created drive will be initialized as a password-store using the same GPG key.

The text file created in this process is used as a keyfile to the vera. It works by encrypting the key using GPG when it is not being used, and decrypting the key at the time of mounting the drive/using `pass open`.

2. If you have `PASSWORD_STORE_DIR` set, copy your backup of the password-store to this location, otherwise copy it to `~/.password-store` (wherever `pass vera` is mounted). Now, pass can be used as usual.

3. When finished, close the password vera: `pass close`

4. To use `pass` again, open the password vera: `pass open`

---
### Usage

```
pass vera 2.0 - A pass extension that adds another layer of encryption
by encrypting the password-store inside a veracrypt drive.

Usage:
    pass vera <gpg-id> [-n] [-t time] [-f] [-p subfolder] [-y] [-s]
                            [-i | -k | --tmp-key] [--for-me] [-r] [-o]
                            [-u [a | c ]] [-c [a | c ]] [-g [JSON | YAML ]]
        Create and initialize a new password vera
        Use gpg-id for encryption of both vera and passwords

   pass open [subfolder] [-i] [-y] [-t time] [-c [a | c ]] [-f]
          Open a password vera

    pass close [-c [a | c ]] [store]
        Close a password vera

Options:
    -n, --no-init        Do not initialize the password store
    -t, --timer          Close the store after a given time
    -p, --path           Create the store for that specific subfolder
    -y, --truecrypt      Enable compatibility with truecrypt
    -k, --vera-key       Create a key with veracrypt instead of GPG
    -o, --overwrite-key  Overwrite existing key
    -i, --invisi-key     Create a key that doesn't exist when it's not being used
        --tmp-key        Generate a one time temporary key
        --for-me         Copy existing password-store to new one when creating vera
    -r, --reencrypt      Reencrypt passwords when creating to new vera (use with --for-me)
    -f, --force          Force operation (i.e. even if mounted volume is active)
    -s, --status         Show status of pass vera (open or closed)
    -u, --usage          Show space available and space used on the container
    -c, --conf           Use configuration file (fzf prompt)
    -g, --gen-conf       Generate configuration file (JSON or YAML)
    -q, --quiet          Be quiet
    -v, --verbose        Be verbose
    -d, --debug          Debug the launchd agent with a stderr file located in $HOME folder
        --unsafe         Speed up vera creation (for testing only)
    -V, --version        Show version information.
    -h, --help           Print this help message and exit.

More information may be found in the pass-vera(1) man page.
```

To view more information, `man pass-vera`.
There is also a markdown version of the man page in this directory (`pass-vera.md`).

---
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

```
(1) "1 hour 5 minutes"      (2) "1hour 5minutes"      (3) "1hr 5 minutes"

(4) "1 hr 5 mins"           (3) "1hr 5mins"           (6) 1hr
```

- An hour is not required when specifying time. Also, if both an hour and minute are specified, place the parameter in quotation marks. The only reason why one would not ever quote the parameter is if something like 1hr is given.

**NOTE [2]:** The `launchd` agent is rounded to the nearest minute and may not close in the exact amount of specified  time.  For  example,  the  time  is `10:02:20` and a `1 minute` timer is given, the `launchd` agent will run in `40 seconds`.


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

The `--invisi-key` or `-i` option will create a key inside of a directory that will automatically shred itself once the vera is mounted. The difference between the invisible key and the temporary key is that the invisible key can be used again, even though it is not the same file that is going to be used. VeraCrypt works in such a way that a key is considered to be the same if it has the same filename and same contents (regardless of the directory). Therefore, after using this option, the key will not be in the user's home directory, and whenever they go to open the vera after closing it, `pass open --invisi-key` must be used in order for the vera to mount, and this will work the same as if the key had never been deleted.

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

#### Create  a password vera using a custom configuration file, as well as use an 'invisible key'

A configuration option was added in version 2.0. It allows for the user to create their own settings for the creation of the veracrypt container. The default configuration can be generated in either a JSON or YAML format by using the command `pass vera --gen-conf (JSON|YAML)`. The file will be in `$XDG_CONFIG_HOME` or `$HOME/.config`. The settings can be modified according to the available options which can be seen in `pass vera`'s man page or by using `veracrypt --text --help`.

If the `--conf` option is specified when creating the `vera`, then the option will once again need to be specified when opening and closing the `vera`. More than one configuration file can be present in the same directory, and for this to work `--conf` must be specified with the `c` or `custom` sub-argument. A selection menu using `fzf` will be displayed for one to choose their configuration.

If there is only one configuration file present, then `--conf` must be specified with the `a` or `auto` sub-argument. There is also an option for `$PASSWORD_STORE_VERA_CONF` to be set to the location of the one and only configuration file. If this is set, then there is no way to use more than one configuration.

```
zx2c4@laptop ~ $ pass vera Jason@zx2c4.com --conf c --invisi-key
  .  Using JSON configuration: vera.json
  Enter password: ****************
  Re-enter password: ****************
  Done: 100.000%  Speed: 6.1 MiB/s  Left: 0 s
  The VeraCrypt volume has been successfully created.

  Enter password for ~/.password.vera: ****************
  (*) Your password vera has been created and opened in: ~/.password-store
  (*) Password store initialized for Jason@zx2c4.com
   .  Your vera is: ~/.password.vera
   .  Your conf is: /$XDG_CONFIG_HOME/pass-vera/vera.json
   .  Your vera key is: /var/~/dl7rz8zgn/T//pass.H9qIkMm/.invisi.key
   .  You can now use pass as usual.
   .  When finished, close the password vera using 'pass close'.
```
---
### Environmental Variables

- `PASSWORD_STORE_VERA`: Path to `veracrypt` executable
- `PASSWORD_STORE_VERA_FILE`: Path to the password vera, by default `~/.password.vera`
- `PASSWORD_STORE_VERA_KEY`: Path to the password vera key file by default `~/.password.key.vera`
- `PASSWORD_STORE_VERA_SIZE`: Password vera size in MB, by default `10`
- `PASSWORD_STORE_VERA_CONF`: Location of configuration file

---
### Installation

**Requirements (minimal versions)**:
- `pass 1.7.3`
- `fzf`, `jq`, and `yq` are needed if more than one configuration is going to be used
- `veracrypt 1.24-Update8`
    - `osxfuse` is a requirement for `veracrypt`
- `launchd 7.0.0`

To make `veracrypt` an executable on the command line, do the following:

```
ln -sv /Applications/VeraCrypt.app/Contents/MacOS/VeraCrypt /usr/local/bin/veracrypt
```

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

---
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

---
### Configuration File

#### JSON

To use multiple `vera` containers, there is an option to create a configuration file. If the command `pass vera --gen-conf` is passed, a JSON configuration template file will be created at `$XDG_CONFIG_HOME/pass-vera/vera.json`. To use this configuration file `-c` or `--conf` must be passed as a parameter when using all three commands (`vera`, `open`, `close`).

#### YAML

If one would prefer to use a YAML file instead, the file type is also supported. Below are all available options for each argument. There is also a [directory](example_configs) of example configuration files in both JSON and YAML.

```yaml
volume-type:    normal # normal, hidden (hidden requires normal first)
create:         /Users/user/.password.vera # any file, full path
size:           15M # any size
encryption:     aes-twofish-serpent
# (1) aes (2) serpent (3) twofish (4) camellia (5) kuznyechik
# (6) aes-twofish (7) aes-twofish-serpent (8) camellia-kuznyechik
# (9) camellia-serpent (10) kuznyechik-aes (11) kuznyechik-serpent-camellia
# (12) kuznyechik-twofish (13) serpent-aes (14) serpent-twofish-aes
# (15) twofish-serpent
hash:           sha-512 # sha-512, whirlpool, sha-256, streebog
filesystem:     exFAT # non, fat, exfat, apfs, mac-os-extended
pim:            0 # positive integer (Personal Iterations Multiplier)
keyfiles:       /Users/user/.password.vera.key # none, any file, full path
random-source:  /dev/urandom # none, urandom
truecrypt:      0 # 1 or 0
unsafe:         0 # 1 or 0
slot:           0 # slot number to mount container
```

---
### Shell Completions

There is a script in the `pass-scripts` folder titled `passcomp.zsh`. It is a `zsh` script that will find the completion file (`_pass`) for `pass` and will modify the subcommands so that the completions will actually work. There are zsh and bash completion files for each subcommand that I have created (`vera`, `open`, `close`) which will be called in `_pass`.

This is the only way that I have figured out how to get the completion to call correctly. The only other way is to use `pass-vera` (with a hyphen), which is not a command.

The script has the following options:

```sh
# the file can be modified and updated by running:
./passcomp.zsh install

# the completions can be removed by running:
./passcomp.zsh remove
```

---
### TODO

- [x] ~~Add a 'do-it-for-me' option~~
- [x] ~~Create a homebrew package~~
- [x] ~~Add configuration file for veracrypt~~
- [ ] Add option to create inner drive
- [ ] Add an option for `MacTomb`
- [ ] Add support for `systemd`

### Feedback / Contribution

Any and all is welcomed.

### Inspiration, Miscellaneous

- This is heavily based off of [`pass-tomb`](https://github.com/roddhjav/pass-tomb). Some pieces of code were taken from it and it provided an outline for me to do this project. This `README` is also structured in a very similar way. `pass-vera` was designed to work with macOS, since macOS doesn't support [dm-crypt](https://wiki.archlinux.org/index.php/dm-crypt) encryption, which is what `pass-tomb` uses. `pass-vera` also uses `launchd` instead of `systemd` to create the timer that will automatically close/dismount the password-store.
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
