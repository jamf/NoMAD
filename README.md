***Main Web Site***

This Gitlab page is used primarily for code storage and issue tracking. For the most up to date information on NoMAD, and installer downloads, please see [nomad.menu](http://www.nomad.menu)

***Current Version***

NoMAD v. 1.1.3(886)

***Development Version***

NoMAD v. 1.1.4

***New Features in Development Version***

- fix for Sign In window not fully displaying
- About menu now in menu
- icon now alternates when clicking on the NoMAD icon in the menu bar
- icon alternates correctly when in dark mode
- Kerberos preferences written out on first launch to further prevent the "Domain not found" error when changing passwords
- Certificate expiration computed better, and won't crash on an already expired cert
- Certificate cleaning will only happen if asked
- User password in the keychain will be looked for in many ways to ensure that the user name case isn't an issue
- better defaults printing in the logs with -prefs
- fix for Sign In Window title not showing correctly when forced
- better handling of when all DCs in a site go down
- action menu fixes to correct actionTrue and to allow for cutom titles and red/yellow/green icons
- ability to get custom list of attributes from AD
- better handling of shares in the Shares Menu when switching users
- nomad://getuser will put entire AD user record into the logs

***NoMAD***

Get all of AD, with none of the bind! From now on you'll have no mo' need of AD.

NoMAD allows for all of the functionality you would want from a Mac bound to
Active Directory without having to actually bind to AD.

Supports macOS 10.10 and above.

***Features***

- Get Kerberos credentials from AD to use for single sign on for all services using Windows Authentication.
- Automatically renew your Kerberos tickets based upon your desires.
- Lock screen menu item.
- Get an X509 identity from your Windows CA.
- One click access to Casper and other self-service applications if installed.
- One click access to creating a Bomgar chat session with a help desk operative, and other support options.
- Admins can push one-line CLI commands to show up as a menu item in NoMAD.
- Admins can specify LDAP servers to use instead of looking them up via SRV records.
- Sync your AD password to your local account. Including keeping the user's local keychain and FileVault passwords in sync.
- Users are warned about impending password expirations.
- Single sign on access to the users Windows home directory.
- Fully AD Site aware.
- Scripts can be triggered on network change and sign in.
- Admins can enable alternate methods of changing passwords beyond Kerberos.

Coming in future versions:

- VPN connection management for built-in VPN types.
- Getting a Kerberos ticket as a side effect of a succesful VPN connection.
- DFS resolution without needing to be bound.

Sample screen shot:

![NoMad Screen Shot](https://gitlab.com/Mactroll/NoMAD/raw/master/screen-shot "NoMAD Screen Shot")


***Have Questions?***

Feel free to report any issues that you're having or feature requests in the Issues section of the project page.

You can find some of the team in #nomad on the Mac Admins Slack. If you're not already a member you can join [here](http://macadmins.org).

You can also discuss the development and get notified of new commits in #nomad-dev.

***Sierra Support***

NoMAD is built and primarily tested on macOS Sierra using Swift 3.

***Experimental Branch***

New features in development, or otherwise risky and irresponsible behavior goes into this branch first.

***Thanks!***

Thanks to a number of people for helping me out on this. Including those of you in the secret channel!

Also a big thanks to @owen.pragel for testing and pontificating.