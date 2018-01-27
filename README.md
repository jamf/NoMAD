***Main Web Site***

This Gitlab page is used primarily for code storage and issue tracking. For the most up to date information on NoMAD, and installer downloads, please see [nomad.menu](http://www.nomad.menu)

***Current Version***

NoMAD v. 1.1.2(797)

***Development Version***

NoMAD v. 1.1.3(872)

***New Features in Development Version***

- Fewer prompts when updating keychain items - build 808
- Match any keychain item account with `<<ANY>>` - build 808
- Recursive group search works with "," in user names - build 808
- When using UPCAlert and a URL to change passowrd, check for password change every 30 seconds - build 808
- Prevent sign in window from closing when SignInAlert is set - build 809
- Write out current AD Site to "ADSite" in preferences - build 809
- Prevent "unknown realm" errors when changing password - build 809
- Allow for both AD password expired and local sync on a seperate password - build 813
- Swift 4, which explains the large build number change - build 853
- Pref key DontShowWelcomeDefaultOff which sets the default Welcome window setting to only show the window once - build 854
- UseKeychainPrompt will now show the Sign In window whenever the user does not have a password in the keychain, even if the user has already signed in at least once - build 854
- Actions menu - build 872

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