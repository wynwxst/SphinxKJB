
### pre-pre-exploit
take a backup of your documents folder in your kindle (To be automated)
go to firmwares/readme.txt
and find your firmware there

### Pre-exploit
reset your kindle, connect to a computer and paste the .bin firmware into the kindle, the only folder you should see is Documents


Eject the Kindle and disconnect the USB cable. You’re going to do this several times throughout the jailbreak process. It is important that you disconnect your Kindle from your computer every time it says to in these directions, otherwise the jailbreak may not work

On your Kindle, head back to the Settings page (Menu > Settings) and then tap Menu > Update Your Kindle.

### Pre-Jailbreak
go to tools/exploit/ and copy the entire contents into the root directory of your kindle


open your browser and type ;installHtml

### Installation (PAPERWHITE MODEL 2 ONLY)
Extract kindle-5.4-jailbreak.zip to the / directory of your kindle


### Final security clean up

go to tools/scleanup and paste the .bin firmware into you / directory of your kindle


Eject and unplug your Kindle.


### Optional (restore back to old firmware aka modern)
You can now update your Kindle to the newest firmware version, though you’ll need to do it manually.

Head to Amazon’s official firmware page and find your model.
Download the newest firmware version (currently 5.8.1 for modern models)
Plug your Kindle into your computer with a USB cable.
Copy the file you just downloaded into the root directory of your Kindle.
Eject and unplug your Kindle.
Head to the Settings page on your Kindle (Menu > Settings), then tap Menu > Update your Kindle, then tap “Ok.”

### Adding package manager


copy the entire contents of the tools/pkg/mrpi/ folder to the root directory of your Kindle. You should end up with an “Extensions” folder and a “mrpages” folder on your Kindle. Kindle Oasis and Kindle Touch 2 owners will need to run an additional command here (everyone else can ignore this). On your Kindle, tap the search bar, then type ;log mrpi to complete the installation.


Go to tools/pkg/kual/ If you’re on a Kindle Paperwhite 1, 2, or 3, or Kindle Touch 2, copy the KUAL-KDK-2.0.azw2 file over to the documents folder on your Kindle. If you’re on a Kindle Oasis or a Kindle Touch 3, copy the Update_KUALBooklet file to the the newly created mrpages folder and install it from there. You’ll find detailed instructions inside the the readme file in the ZIP archive.


On your Kindle, tap Menu > Settings > Menu > Update Your Kindle. Tap “Ok.”

### Next?
go to https://www.mobileread.com/forums/showthread.php?t=180113 and check out all the packages


### Installing packages
paste the extensions into the mrinstaller folder in the / directory of your kindle

(TO DO: add automation and support for kindle 2.x)
