# ProPresenter-Library-Wrapper-PS
Wrapper application for ProPresenter on Windows that manages the library as a git repository.

## THE PROBLEM WE ARE TRYING TO SOLVE:

- Running ProPresenter across multiple devices is difficult as there is no real method of keeping the libraries across devices in sync with one another
- The methods provided by Renewed Vision (ProPresenter Cloud Sync and ProPresenter Local Sync) are basic at best, requiring the user to manually run the actions and only working on all files at one time or none at all (lacking granularity)
- Cloud sync services e.g. Dropbox perform a continuous sync, which means that theoretically someone can change library items remotely while you're running an event. What's more, there is no master data source in this situation - all changes are synced.
- ProPresenter aggressively writes to its library files. The second you make a change, that is saved - even if it's not something that you want to keep in the long term. This means that any changes made that are event-specific have to be undone next time you want to use that library item
- Essentially every time you approach a ProPresenter machine, the library is in an unknown, unpredictable state: however the last person has left it. There is currently no data integrity.


## THE SOLUTION:

The proposed solution to the above is checking the library into version control (like git). This set of scripts aids with making this slightly more user friendly and taking out some of the manual work that would be required by semi-automating the git workflows.


## INSTALLING THE APP:

Prerequisite is that you have git installed.

Windows - this is essentially just a bunch of powershell scripts. These can just be copied to a folder (recommend under 'Program Files') and the shortcut updated to point to the correct folder and copied to the desktop.
MacOS - this is essentially a bunch of shell scripts in an application bundle. This bundle can be copied to the Applications folder

In both cases, there are some system variables that are required for the app to work. These are listed in the envConfig.properties file. On Windows, these should be set as environment variables (you may either do that manually or run the installScript.ps1), on macOS this envConfig.properties file should be copied into the application bundle's Resources folder.

Most of these properties are fairly self-explanatory. Where properties are Windows filepaths, please escape backslashes with another backslash. No need to escape spaces.

- ProPresenterEXE (windows only) = the filepath to the ProPresenter executable file on your machine
- PPLibraryPath = full filepath to the location of your library repository on the machine
- PPRepolocation = the URL path to the library repository on github (i.e. everything after www.github.com if you navigate to your library repo)
- PPLabelLocation = the location of your labels file on the disk
- PPPlaylistLocation = the location of your playlist file on disk
- PPLiveDevice = whether or not this device is expected to be used for live playback (i.e. whether pulling is optional)
- PPReadOnlyDevice = whether or not this device can be used to upload changes back to the library repository
- PPLibraryAuthToken = a github auth token generated from your account so that the app can open pull requests to your library repository. Details of how to generate this can be found here: https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token

You can either do all this install manually or you can run the provided install script. This will automatically set these properties from the properties file on your disk (with the exception of the auth token), clone your library repository to the given location and then help you to generate an auth token from your github credentials.


## HOW THE APP WORKS:

This consists of two fairly basic shell scripts:

1) When you run ProPresenter Library Wrapper

- This first script does a hard pull down from the master branch of your library repository. It essentially sets your local library back to baseline so that it is in a known state for you to work on.
- It also clears all old playlists from ProPresenter and copies the labels for your library from the master repository
- If you have installed this device with PPLiveDevice property set to 1 then this script can be opted out of (the logic being that if ProPresenter crashes while you're live you may need to get back to your working playlist in a hurry)
- It is recommended that you always opt to pull down the master library (by typing 'y' in this script or setting as a non-live device) unless you have a very good reason not to. This ensures all your work always starts from baseline state.


2) When you close ProPresenter

- This script runs when it detects that ProPresenter has been closed (as long as it's not a read-only device)
- This essentially cycles through files in the library that have been updated during your session and asks if you would like to save the changes you've made on them back to the master version of your library (i.e. the git repository)
- Technically, this actually works by pushing up a branch of your repository and opening a pull request against master. This could allow for approvals of changes if you so desire, but you can also set up a github action on your master repository to automatically manage the merges (e.g. using something like this https://github.com/marketplace/actions/simple-merge)
- If there are any merge conflicts between someone's source branch and master then these will require manual resolution by someone with some knowledge of git.
- It is recommended, if you're updating the library, that you ensure that the item is in the exact state that you'd like to find it every time you open ProPresenter when you add it e.g. make sure it isn't in some strange arrangement/using an unusual template/covered in video backgrounds


## SETTING UP YOUR LIBRARY REPOSITORY:

If you are using Pro6, please use the following repository structure:

ROOT<br>
|___Config Templates<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|___macOS_Default.pro6pl<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|___macOS_LabelSettings.xml<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|___windows_Default.pro6pl<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;|___windows_LabelPreferences.pro6pref<br>
|___Library 1<br>
|___Library 2<br>
etc.

For pro6, the config templates folder will contain a default set of playlists (recommend empty, and your labels files for each OS). Please name as indicated above.

If you are using Pro7, then your repository should be structured as the default Pro7 directory is in your Documents directory. I recommend that you write a .gitignore file and ignore the Media directory as well as config ones (in the latter case you run the risk of trying to sync machine-specific settings). If you already have a repository set up then the install script will automatically pull it into your Pro7 directory.

If you wish changes to automatically be merged to master (rather than having a manual approval) then you may wish to set up a github action to automatically merge pull requests e.g. https://github.com/marketplace/actions/simple-merge



## RECOMMENDATIONS FOR KEEPING YOUR LIBRARY UNDER CONTROL:

1) Ensure that songs are in the exact state in which you would like to find them every time you open the software when you save back to the master library
2) Ensure that there are no templates, media or backgrounds linked to songs when you save to the master library as these may not exist on the device that you sync down to (or may exist in a different location)



## EXPECTATIONS FOR HOW THE APP IS TO BE USED:

- The expectation is that this application is used to always return your ProPresenter library to a known state and that event-specific changes aren't automatically left over in the library
- As such, the expected user workflow is as follows:

1) User runs 'ProPresenter Library Wrapper' (use instead of usual ProPresenter executable) - this sets your library to baseline
2) User sets up playlist for an event/adds to or edits songs in the library
3) If the user wants to keep event-specific changes (i.e. things that you don't want to be there in the library every time you open the software) then the expectation is that they export their playlist as a bundle (either including or excluding media - recommend include if not going to play back on the same machine)
4) The user closes ProPresenter and adds any changes to the master library that they would like to appear every time they open the software (or doesn't)
5) Next time you open ProPresenter, the library will contain only the things that exist on the master.
6) If you want to play back changes that were made only for an individual event then all you have to do is import the playlist that you prepared earlier over your baseline library.
