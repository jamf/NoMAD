#  NoMAD Actions Readme

This file lays out the design goals of the Actions Menu that you can add into NoMAD and how to use it.

## Philosophy

The Actions Menu is composed of "actions" which are defined by a prefrence file in the "menu.nomad.actions" domain. In this file Actions are listed as an array of dictionaries with each dictionary comprising one action. NoMAD Actions are simultaneously attempting to be highly configurable without being overly complicated.

## Anatomy of an action

An action is comprised of some meta data and then four phases. Each phase has a collection of Commands in them. These commands have the Command itself and then a CommandOptions that can modify the command. Commands can execute external scripts or use the built in functions included with Actions. The only required part of the Action is the name of the action, all the other parts are optional. To break out a sample Action

| Attribute  |Definition   |Type   | Required
|---|---|---|---|---|
|Name| Plaintext name of the Action. Will be used for the menu name if a Title isn't given | String | yes
|Title| Command Set that determines the name of the menu item | Dictionary | no
| Show | Command Set that determine if the item should be shown in the menu | Array | no
| Action | Command Set that make up the actual Action itself | Array | no
| Post | Command Set that will happen after the Action commands are run | Array | no
| GUID | Unique ID for the Action | String | no
|Connected | If the action set should only be run when connected to the AD domain | Bool | true
|Timer| Length in minutes between firing the Action | Int | 15
|ToolTip| The text to be shown when hovering over the menu item | String | Click here for support

* Note that the Title command set can only have one command
* If the Title command returns "false" or "true" the text of the title won't be updated. Instead a red, in the case of "false", or green dot will be next to the menu item and the title will be the Name of the action set.
* An Action with the Name of "Separator" will become a separator bar in the menu.

## Commands

NoMAD has a number of built-in commands to make things easy, however, since one command is to execute a script, you'll quickly be able to make any unique commands that you want.

Each command has a CommandOptions value that determines what the command does. All options are strings. All commands can return results. A result of "false" is used by the Show action to prevent the menu item from being shown.

| Command | Function | Options
|---|---|---|
| path | Excute a binary at a specific file path | The path to execute
| app | Launch an app at a specific file path | The path to the application
| url | Launch a URL in the user's default browser | The URL to launch
| ping | Ping a host, will return false if the host is unpingable | The host to ping
| adgroup | Determine if the current user is a member of an AD group | The group to test with
| alert | Display a modal dialog to the user | Text of the dialog
|notify| Display a notification in the notification center | Text of the notification
|false| A command that always returns false | Anything

## Workflow

* On launch NoMAD looks at the `menu.nomad.actions` preference domain and reads in any Actions.
* For each Action, NoMAD will run the Show command set to determine if the menu item should be shown. Note that all commands in the Show command set have to return positive for the menu item to be shown.
* For items that pass the Show test, NoMAD will then run the Title command set to get the text of the menu item. If no command set has been configured, the Action name will be used instead.
* An item that is clicked on will cause the item's Action command set to be run.
* Following the Action set running, the Post set will then be run acting on the result of the Action set.
* Every time NoMAD updates (every 15 minutes, network change or NoMAD menu interaction) the Actions items will be updated with the same process.

## Still to come

There's a few more features that we'd like to get down before release. Currently all of these are achievable.

* Triggers - Trigger actions based upon system events such as:
	* Network change
* Action -> Post - Allow actions to send messages/status to the Post command set
