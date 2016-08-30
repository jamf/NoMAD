***NoMAD***

Get all of AD, with none of the bind! From now on you'll have no mo' need of AD.

NoMAD allows for all of the functionality you would want from a Mac bound to
Active Directory without having to actually bind to AD.

***Features***

- Get Kerberos credentials from AD to use for single sign on for all services using Windows Authentication.
- Automatically renew your Kerberos tickets based upon your desires.
- Optional lock screen menu item.
- Get an X509 identity from your Windows CA.
- One click access to Casper self-service if installed.
- One click access to creating a Bomgar chat session with a help desk operative.
- Admins can push one-line CLI commands to show up as a menu item in NoMAD.
- Admins can specify LDAP servers to use instead of looking them up via SRV records.
- Sync your AD password to your local account.
- Users are warned about impending password expirations.
- Customize user's help options between a Bomgar URL, web URL or local application path.
- AD Site aware

Coming in future versions:

- VPN connection management for built-in VPN types.
- Getting a Kerberos ticket as a side effect of a succesful VPN connection.
- Mounting of arbitrary shares based upon configured values.
- DFS resolution without needing to be bound.
- Put x509 certificate into an 802.1x profile for use with wireless networks.

Sample screen shot:

![NoMad Screen Shot](https://gitlab.com/Mactroll/NoMAD/raw/master/screen-shot "NoMAD Screen Shot")

***Documentation***

[Wiki](https://gitlab.com/Mactroll/NoMAD/wikis/home "NoMAD Wiki")

***Current Version***

v. .9 Public Beta 2 - Most things work, but we need some testing.

[NoMAD-PB2.zip](/uploads/68b3c828d9622b3f86affddc9dc1687f/NoMAD-PB2.zip)

***Video Walkthrough***

If you want to get a better idea of what NoMAD can do for you, here's a quick walkthrough of some of the major features.

[NoMAD video Walkthrough](https://www.youtube.com/watch?v=Z27GOBl1bWY)

***Have Questions?***

Feel free to report any issues that you're having or feature requests in the Issues section of the project page.

Also you can find some of the team in #nomad on the Mac Admins Slack. If you're not already a member you can join [here](http://macadmins.org).

***Sierra Support***

While not always tested on Sierra, it should work fine. Currently the project is in Swift 2.2. It almost nearly compiles in Swift 3.

***Experimental Branch***

New features in development, or otherwise risky and irresponsible behavior goes into this branch first.

***Thanks!***

Thanks to a number of people for helping me out on this. Including those of you in the secret channel!

Also a big thanks to @owen.pragel for testing and pontificating.