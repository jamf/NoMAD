***Main Web Site***

This gitlab page is used primarily for code storage and issue tracking. For the most up to ddate information on NoMAD, and installer donwloads, please see [nomad.menu](http://www.nomad.menu)

***Current Version***

NoMAD v. 1.1(772)

***Development Version***

NoMAD v. 1.1.1(781)

***New Features in Development Version***

- Norwegian Localization - build 778
- Croatian Localization - build 778
- Support for sites with no DCs listed. NoMAD will fall back to globally available DCs - build 778
- Better support for < 10.12 systems and the Welcome Screen - build 778
- Switch to Xcode 9 and Swift 3.2 - build 778
- MenuFileServers - Sets the menu item title for the File Servers menu - build 781
- UseKeychainPrompt - Prompts the user to sign in if there's no entry in the keychain, regardless of if they have tickets - build 781
- Welcome window is now titled the same as the Application - build 781
- Fix for shares being mis-escaped for spaces and other non-compliant characters - build 783
- MessageUPCAlert - customize UPC alert notification text - build 784
- Fix for URL encoding with File Shares - build 789
- Fix for expired certificates causing menu to show strangely - build 789
- Fix for non-automounted shares not being able to mount - regression from 1.1 - build 791
- AutoRenewCert - Int - Key to specify number of days to go on a cert before automatically renewing - build 791
- Ability to have multiple Chrome domains specified for NoMAD to add into the Chrome preferences - build 792

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
- Mounting of arbitrary shares based upon configured values.
- DFS resolution without needing to be bound.
- Put x509 certificate into an 802.1x profile for use with wireless networks.

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