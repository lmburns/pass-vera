---
date: March 2021
section: 1
title: pass-vera
---

NAME
====

pass-vera - A **pass**(1) extension that adds another layer of
encryption by encrypting the password-store inside a **veracrypt**(1)
drive.

SYNOPSIS
========

**pass vera** *\<gpg-id\>* \[**-n**\] \[**-i** \| **-k** \|
**\--tmp-key**\] \[**-o**\] \[**-y**\] \[**-p** *path*\] \[**-q** \|
**-v**\] \[**\--for-me**\] \[**-r**\] \[**-s**\] \[**-u**\] \[**-c**\]
\[**-g**\] \[**-t** *time*\]\
**pass open** \[**-f**\] \[**-q** \| **-v**\] \[**-c**\] \[**-y**\]
\[**-i**\] \[**-t** *time*\]

\
**pass close** \[**-f**\] \[**-q** \| **-v**\] \[**-c**\]

DESCRIPTION
===========

The file and directory names in the password-store that is created by
**pass**(1) are not encrypted and are available for anyone with access
to the computer to see. **pass vera** provides a solution to this
problem by moving the password-store to an encrypted drive that is
created by **veracrypt**(1). The password-store can be encrypted (i.e.,
the folder doesn\'t exist) when it is not being used.

The same GPG key (by default) is used to encrypt passwords and the
veracrypt drive, therefore one doesn\'t need to manage another key.
There is also an option to move an existing password-store to the
location of the new one without any manual intervention. Moreover,
pass-vera can be given a timer as an argument that will automatically
close the password-store after the specified amount of time has passed.

A configuration file can be used to create and mount the VeraCrypt
container. Using the command **pass vera \--gen-conf** will generate a
configuration file located at *\$XDG_CONFIG_HOME/pass-vera/vera.JSON*.
To use this configuration file, specify **\--conf** when using all three
commands. *NOTE*: be aware that (at least at the moment)
**\--invisi-key** or **\--tmp-key** are unable to be used when
specifying **\--conf**. See the **CONFIGURATION** section for all
available options.

**BEFORE USING THIS PROGRAM:**

:   Make a backup of your password-store directory. Do this even if you
    plan on specifying the **\--for-me** argument which will transfer
    over the pre-existing password-store for you. Once the vera is
    created and the passwords are moved into the vera, only then should
    you delete the backup.

```{=html}
<!-- -->
```

**WORKFLOW**

:   

    **(1)** Create a password vera with **pass vera** \<*gpg-id*\>. Type
    anything in the text file that opens (make sure to remember it).
    Then, one will be prompted for a password to be entered for the
    veracrypt drive itself (it does not have to be the same as the text
    file). The \"vera\", is created and mounted in *PASSWORD_STORE_DIR*
    (or, if unset, then *\~/.password-store*). Finally, the newly
    created drive will be initialized as a password-store using the same
    GPG key.

The *text file* created in this process is used as a keyfile to the
vera. It works by encrypting the key using GPG when it is not being
used, and decrypting the key at the time of mounting the drive/using
**pass open**.

> **(2)** If you have *PASSWORD_STORE_DIR* set, copy your backup of the
> password-store to this location, otherwise copy it to
> *\~/.password-store*. Now, pass can be used as usual.
>
> **(3)** When finished, close the password vera: **pass close**.
>
> **(4)** To use pass again, open the password vera: **pass open**.

COMMAND
=======

**pass vera** *\<gpg-id\>* \[ **\--no-init**, **-n** \] \[**\--timer**=*time*, **-t** *time*\]

:    \[ **\--path**=*subfolder*, **-p** *subfolder* \]
    \[**\--truecrypt**, **-y**\] \[**\--vera-key**, **-k**\]
    \[**\--overwrite-key**, **-o**\] \[**\--tmp-key**\]
    \[**\--invisi-key**, **-i**\] \[**\--force**, **-f**\]
    \[**\--status**, **-s**\] \[**\--gen-conf**\] \[**\--conf**,
    **-c**\] \[**\--usage**, **-u**\] \[**\--for-me**\]
    \[**\--reencrypt**, **-r**\]

Create and initialize a new password vera. This command must be run
first, before a password-store can be used. The user will be prompted
with a blank text document where anything can be entered (be sure to
remember it), and then prompted again to enter a password that will
encrypt the veracrypt drive.

If no key type is given (**\--vera-key**, **\--invisi-key**, or
**\--tmp-key**) then the blank text document that is prompted will be
encrypted, and the decrypted version of that file will be used as the
key for the vera. The key will remain encrypted until the user opens the
vera, and then once the key has finished its purpose it will be
re-encrypted. If this key is lost, all the data within the vera will
become inaccessible.

Use *gpg-id* for the encryption of both passwords and vera. Multiple
gpg-ids may be specified to encrypt the vera and each password/directory
within it.

If **\--no-init**, **-n** is specified, the password-store is not
initialized. By default, pass-vera initializes the password-store with
the same key(s) that generated the vera. The purpose of this argument is
to give the user the option to initialize the password-store with a
different key or set of keys.

If **\--timer**, **-t** is specified, along with a *time* argument, the
password store will automatically close using a **launchctl**(1) agent
that runs a script after the given time. The agent will be unloaded once
the pass vera is closed and dismounted, then a notification will be sent
using an osascript.

*Note*: The launchctl agent is rounded to the nearest minute and may not
close in the exact amount of specified time. For example, the time is
10:02:20 and a 1 minute timer is given, the launchctl agent will run in
40 seconds.

**TIMER FORMAT**

:   Must match one of the following:

    \
    **(1)** \"1 hour 5 minutes\" **(2)** \"1hour 5minutes\" **(3)**
    \"1hr 5 minutes\"

    \
    **(4)** \"1 hr 5 mins\" **(3)** \"1hr 5mins\" **(6)** 1hr

    \
    *Note*: An hour is not required when specifying time. Also, if both
    an\
    hour and minute are specified, place the parameter in quotation
    marks. The\
    only reason why one would not ever quote the parameter is if
    something like\
    1hr is given.

If **\--path** or **-p** is specified, along with a *subfolder*, a
specific password vera using the given gpg-id or a given set of gpg-ids
is assigned to that specific subfolder of the password-store. The
*subfolder* is not a full path, only a folder name that will be created
in the process of creating the vera.

If **\--truecrypt** or **-y** is specified, the vera will have enabled
TrueCrypt compatibility mode to permit the mouting of volumes that were
created using TrueCrypt versions 6.x or 7.x. This option can be used by
setting the *PASSWORD_STORE_VERA_FILE* environment variable to a file
that is used by TrueCrypt.

If **\--vera-key** or **-k** is specified, /dev/urandom will be used to
create a key specifically for the vera drive. This is stored in your
home folder and is specified by the *PASSWORD_STORE_VERA_KEY*
environment variable. If this key is lost, all the data within the vera
will become inaccessible.

If **\--overwrite-key** or **-o** is specified, the existing key that is
used by pass vera to mount the drive will be overwritten with the new
kind of key that is specified. This option should be used only whenever
one is having some sort of issue setting pass-vera up, and has backed up
all of the data on the existing vera drive.

If **\--invisi-key** or **-i** is specified, the key will be created
inside of a directory that will automatically shred itself once vera is
mounted. The difference between the invisible key and the temporary key
is that the invisible key can be used again, even though it is not the
same file. VeraCrypt works in a way such that a key is considered to be
the same if it has the same filename and same contents. Therefore, after
using this option, later when one is opening the vera, **pass open
\--invisi-key** must be used and it will work the same as if the key had
never been deleted.

If **\--tmp-key** is specified, a one-time key will be created and used
as the keyfile for the vera. All data that is placed within this drive
while it is mounted will no longer be accessible when it is dismounted.

If **\--for-me** is specified, pass vera will copy an existing
password-store to the location of the new password-store whenever it is
being created. When using this option, it would still be wise to backup
the password-store directory until one has made sure that it does work.

If **\--reencrypt** is specified, pass vera will re-encrypt the files
within the existing password-store when transfering them over the
location of the new password-store. This option is only able to be used
whenever **\--for-me** is also used.

If **\--gen-conf** or **-g** is specified, pass vera will create a
*.JSON* configuration file at the location
*\$XDG_CONFIG_HOME/pass-vera/vera.JSON* and will exit.

If **\--conf** or **-c** is specified, pass vera will use the options
that are specified within this file. The location of the file is
*\$XDG_CONFIG_HOME/pass-vera/vera.JSON*. A *.YAML* file can also be
used. Examples are located at the bottom of this page in
**CONFIGURATION**.

If **\--force** is specified, the password vera will create or mount the
password-store to a volume that is in use, or it will force dismount a
volume that is in use. This can also overwrite files, so use cautiously.

If **\--status** or **-s** is specified, the status of the vera (mounted
or not) will be printed on the screen.

If **\--usage** or **-u** is specified, the space used, space available,
and percentage of space used on the container will be displayed.

**pass open** \[**\--timer**=*time*, **-t** *time*\] \[**\--truecrypt**, **-y**\]

:    \[**\--invisi-key**, **-i**\] \[**\--force**, **-f**\]
    \[**\--conf**, **-c**\] \[*subfolder*\]

Open a password vera. If a *time* parameter is given (e.g., \"1 hour 5
minutes\") then a launchctl agent will be loaded. After the specified
time interval, a script will run that will dismount the drive and unload
the agent.

**ADD MULTIPLE TIMERS**

:   If **\--timer** or **-t** is specified, along with *time* argument,
    the password store will be automatically closed using a launchctl
    agent that runs a script after a given time. If a \'.timer\' file
    was already present in the store, this time will be updated, which
    updates the launchctl agent. Therefore, multiple timers can be
    passed, one extending upon the next.

For example, if you open the password vera using **pass open
\--timer=***5 minutes*, and then one minute later decide to add more
time to the already running timer by using **pass open \--timer=***2
minutes*, the password vera will close in 6 minutes.

If **\--invisi-key** or **-i** was specified when creating the
password-vera, then when opening the password-vera, this argument must
be specified again.

If **\--truecrypt** or **-y** was specified when creating the
password-vera (by setting *PASSWORD_STORE_VERA_FILE* to a file created
by TrueCrypt), then to open the password-vera, **\--truecrypt** or
**-y** must also be specified.

If **\--conf** or **-c** is specified, pass vera will use the
information located within the configuration file
(*\$XDG_CONFIG_HOME/pass-vera/vera.JSON*). The *\--ivisi-key* and
*\--tmp-key* options are unable to be used when using a configuration
file at this point.

If **\--force** is specified, the password vera will create or mount the
password-store to a volume that is in use, or it will force dismount a
volume that is in use. This can also overwrite files, so use cautiously.

If *subfolder* is specified, the password-store will be opened in the
subfolder. Otherwise, pass vera will open in *PASSWORD_STORE_DIR* if
set, and if not, then it will open in *\~/.password-store*.

**pass close** \[**\--force**, **-f**\] \[**\--conf**, **-c**\] \[*store*\]

:   

Close a password vera.

If **\--force** is specified, the password vera will create or mount the
password-store to a volume that is in use, or it will force dismount a
volume that is in use. This can also overwrite files, so use cautiously.

If *store* is specified, pass close will try to close the store
associated with the file. Otherwise, pass close will close the the vera
opened with the file *PASSWORD_STORE_VERA_FILE*. VeraCrypt works in such
a way that a file is created and when mounted to a computer it becomes
an external drive. When pass-vera closes the password-store it is
dismounting the drive at the location of the file that is storing all of
the data.

OPTIONS
=======

**-n, \--no-init**

:   Do not initialize the password-store

```{=html}
<!-- -->
```

**-g, \--gen-conf**

:   Generate a JSON configuration file

```{=html}
<!-- -->
```

**-c, \--conf**

:   Use the configuration file placed at
    \$XDG_CONFIG_HOME/pass-vera/vera.JSON

```{=html}
<!-- -->
```

**-t, \--timer**

:   Close the store after a given time

```{=html}
<!-- -->
```

**-p, \--path**

:   Create the store for that specific subfolder

```{=html}
<!-- -->
```

**-y, \--truecrypt**

:   Enable compatiblity with TrueCrypt

```{=html}
<!-- -->
```

**-k, \--vera-key**

:   Create a key with /dev/urandom instead of GPG

```{=html}
<!-- -->
```

**-i, \--invisi-key**

:   Create a key that is deleted after it is used, though it can be
    re-used

```{=html}
<!-- -->
```

**\--tmp-key**

:   Create a one-time key for a one-time accessible vera

```{=html}
<!-- -->
```

**-o, \--overwrite-key**

:   Overwrite existing key in favor of the one specified

```{=html}
<!-- -->
```

**\--for-me**

:   When creating the password-vera, copy the existing password-store
    over

```{=html}
<!-- -->
```

**-r, \--reencrypt**

:   When creating the password-vera and using **\--for-me**, re-encrypt
    all files during the transfer process

```{=html}
<!-- -->
```

**-f, \--force**

:   Force the vera operations (i.e., even if mounted volume is in use)

```{=html}
<!-- -->
```

**-s, \--status**

:   Show status of pass vera, (i.e., open or closed)

```{=html}
<!-- -->
```

**-u, \--usage**

:   Show the space used and space available on the vera container

```{=html}
<!-- -->
```

**-q, \--quiet**

:   Do not print any messages

```{=html}
<!-- -->
```

**-v, \--verbose**

:   Print more messages

```{=html}
<!-- -->
```

**-d, \--debug**

:   Enable debugging of the launch agent. The path of the stderr file
    will be *\$HOME/pass-vera-stderr.log* and the path of the stdout
    file will be *\$HOME/pass-vera-stdout.log*

```{=html}
<!-- -->
```

**\--unsafe**

:   Does not encrypt free space when creating a device-hosted volume

```{=html}
<!-- -->
```

**-V, \--version**

:   Show version information

```{=html}
<!-- -->
```

**-h, \--help**

:   Show usage message

EXAMPLES
========

Create a new password vera

:   **zx2c4\@laptop \~ \$ pass vera Jason\@zx2c4.com**\
    (\*) GPG key created\
    Enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Re-enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Done: 100.000% Speed: 6.4 MiB/s Left: 0 s\
    The VeraCrypt volume has been successfully created.\
    Enter password for \~/.password.vera:
    \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    (\*) Your password vera has been created and opened in
    \~/.password-store.\
    (\*) password-store initialized for Jason\@zx2c4.com.\
    . Your vera is: \~/.password.vera\
    . Your vera key is: \~/.password.key.vera\
    . You can now use pass as usual.\
    . When finished, close the password vera using \'pass close\'.

```{=html}
<!-- -->
```

Open a password vera

:   **zx2c4\@laptop \~ \$ pass open**\
    Enter password for \~/.password.vera:
    \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    (\*) Your password vera has been opened in \~/.password-store.\
    . You can now use pass as usual.\
    . When finished, close the password vera using \'pass close\'.

```{=html}
<!-- -->
```

Close a password vera

:   **zx2c4\@laptop \~ \$ pass close**\
    (\*) Your password vera has been closed.\
    . Your passwords remain present in \~/.password.vera.

```{=html}
<!-- -->
```

Create a new password vera and set a timer

:   **zx2c4\@laptop \~ \$ pass vera Jason\@zx2c4.com \--timer=\"1
    hour\"**\
    (\*) GPG key created\
    Enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Re-enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Done: 100.000% Speed: 6.4 MiB/s Left: 0 s\
    The VeraCrypt volume has been successfully created.\
    Enter password for \~/.password-store:
    \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    (\*) pass-close.password.vera.plist loaded\
    (\*) Your password vera has been created and opened in
    \~/.password-store.\
    (\*) password-store initialized for Jason\@zx2c4.com.\
    . Your vera is: \~/.password.vera\
    . Your vera key is: \~/.password.key.vera\
    . You can now use pass as usual.\
    . This password-store will be closed in: 1 hour\

```{=html}
<!-- -->
```

 Open a password vera, set a timer, and add additional time after 5 minutes have passed

:   **zx2c4\@laptop \~ \$ pass open \--timer=\"10 minutes\"**\
    Enter password for \~/.password.vera:
    \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    (\*) pass-close.password.vera.plist loaded\
    (\*) Your password vera has been opened in \~/.password-store.\
    . You can now use pass as usual.\
    . This password-store will be closed in: 10 minutes\
    **zx2c4\@laptop \~ \$ pass open \--timer=\"10 minutes\"**\
    w The veracrypt drive is already mounted, not opening\
    (\*) pass-close.password.vera.plist timer has been updated\
    (\*) Your password vera has been opened in \~/.password-store.\
    . You can now use pass as usual.\
    . This password-store will be closed in: 15 minutes

```{=html}
<!-- -->
```

Create a password vera using an \'invisible key\' & copy an existing password-store (*PASSWORD_STORE_DIR*)

:   **zx2c4\@laptop \~ \$ pass vera Jason\@zx2c4.com \--for-me
    \--invisi-key**\
    (\*) Invisible key created\
    Automatically transferring password stores:\
    \[ /Users/Jason/.password-store/ \]\
    Enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Re-enter password: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    Done: 100.000% Speed: 6.1 MiB/s Left: 0 s\
    The VeraCrypt volume has been successfully created.\
    Enter password for \~/.password.vera:
    \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\*\
    (\*) Your password vera has been created and opened in
    \~/password-store.\
    (\*) Password store initialized for Jason\@zx2c4.com\
    . Your vera is: \~/.password.vera\
    . Your vera key is: /var/\~/dl7rz8zgn/T//pass.H9qIkMm/.invisi.key\
    . You can now use pass as usual.\
    . When finished, close the password vera using \'pass close\'.

ENVIRONMENT VARIABLES
=====================

*PASSWORD_STORE_VERA*

:   Path to veracrypt executable

*PASSWORD_STORE_VERA_FILE*

:   Path to the password vera, by default *\~/.password.vera*

*PASSWORD_STORE_VERA_KEY*

:   Path to the password vera key file by default
    *\~/.password.key.vera*

*PASSWORD_STORE_VERA_SIZE*

:   Password vera size in MB, by default *10*

*PASSWORD_STORE_VERA_CONF*

:   Location of configuration file

CONFIGURATION
=============

The configuration file can be made in both *JSON* and *YAML* files. JSON
files are preferred and are generated when using **pass vera
\--gen-conf**. In the example YAML configuration file below, available
options are mentioned above.

*YAML*

:   \
    **volume-type: normal** *\# normal, hidden (hidden requires normal
    first)*\
    **create: /Users/user/.password.vera** *\# any file, full path*\
    **size: 15M** *\# any size*\
    **encryption: AES** *\# aes, serpent, twofish, camellia,
    kuznyechik*\
    **hash: sha-512** *\# sha-512, whirlpool, sha-256, streebog*\
    **filesystem: exFAT** *\# non, fat, exfat, apfs, macOS extended*\
    **pim: 0** *\# positive integer (Personal Iterations Multiplier)*\
    **keyfiles: /Users/user/.password.vera.key** *\# none, any file,
    full path*\
    **random-source: /dev/urandom** *\# none, urandom*\
    **truecrypt: 0** *\# 1 or 0*\
    **unsafe: 0** *\# 1 or 0*\
    **slot: 0 ***\# slot to mount container*

COMPLETIONS
===========

*ZSH*

:   There are three *.zsh*** scripts that should be installed
    automatically when calling the Makefile; however, there is a zsh**
    script titled *passcomp*** which will modify pass\'s completion file
    (***\_pass***) to allow for the three subcommands** associated with
    **pass vera to work. The only way I have figured out how to call
    them without this is to use ***pass-vera***,** though this is not a
    command.

*BASH*

:   There is a bash completion file that I have not tested, though it
    should work.

SEE ALSO
========

**pass(1),** **veracrypt(1),** **launchctl(1),** **pass-clip(1)**
**pass-ssh(1),** **pass-import(1),** **pass-otp(1)**

AUTHORS
=======

**pass vera**

was written by [Lucas Burns](mailto:lucas@burnsac.xyz).

COPYING
=======

This program is free software: you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation, either version 3 of the License, or (at your
option) any later version.

This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
Public License for more details.

You should have received a copy of the GNU General Public License along
with this program. If not, see \<http://www.gnu.org/licenses/\>.
