RubySync: not-so-friendly rsync GUI
===================================
RubySync is a GUI frontend to `rsync` tasks. It is inspired by (and shares some code from) [Winton's `rbackup`](http://github.com/winton/rbackup) Ruby gem. RubySync mostly respects the same profile syntax as defined by Winton's work.

How-To
------
Launch the file and write a sync profile in the main window. Syntax is YAML. You can group and nest profiles by indenting. Actual sync profiles (*i.e.* not groups) must have `source:` and `destination:` keys. Optional keys are also allowed, and at the moment the following options are accepted:

* `include: [array of globs]`
* `exclude: [array of globs]`
* `delete: <true|false>`
* `update: <true|false>`
* `dry: <true|false>`

the last three keys correspond to the options `--delete`, `--update`, and `--dry-run` of `rsync` command.

Once defined the profiles, click on the **Validate** button: if the button is valid, the dropdown menu in the toolbar populates with the available profiles. Select the profile you want and click on **Rsync** button. Watch the `rsync` output on the right text window of the split pane.

Preferences
-----------
The preference pane gives the possibility to switch from standard app mode to menubar item. Moreover, it allows to select the default behavior for `delete`, `update`, and `dry` options, *i.e.* what to do when a profile lacks of explicit option keys.

Growl
-----
RubySync supports Growl notifications, provided you have [Growl installed](http://growl.info).

Experimental features
---------------------
The experimental branch now supports *mirroring*. It means that if a profile has the `:mirror` key set to `true`, after the first forth synchornization, a backward synchronization will automatically occour. In this case the `--delete` option is automatically disabled and the `--update` option is enforced, regardless to any other settings.

*WARNING 1*: this only works when the `:source` is a local path and the `:destination` is a remote ssh address.

*WARNING 2*: no check whatsoever is made on profile logic consistency, so loss of data is possible! before trying, enable the `:dry` key!