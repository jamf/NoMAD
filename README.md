# NoMAD Projects Archived

Jamf has decided to archive the NoMAD repos on GitHub. Going forward they aren’t going to receive any updates. 

While they are read-only, they aren’t being deleted. That means that anyone who wants to fork and use the code is welcome to do so. Everything remains MIT licensed and open source.

The projects are still here and still open source, they just won’t be maintained by Jamf. Any existing issues or PRs have been closed.

You can see the official announcement on the [Jamf Blog](https://www.jamf.com/blog/jamf-to-archive-nomad-open-source-projects/).

There is still an active user community on the [MacAdmins Slack nomad channel](https://macadmins.slack.com/archives/C1Y2Y14QG).

As always, have fun and read the man pages.

macshome

# NoMAD 1.x

The NoMAD 1.x releases have come to a close now with NoMAD 2 closing in on release. You can find the most current release (1.3.0) of NoMAD here in the releases section.

Please take a look at the [NoMAD 2](https://github.com/jamf/NoMAD-2) repo for current and ongoing work and discussions.

Thanks for all the support!

--

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
