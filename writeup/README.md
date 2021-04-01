# WRITEUP


### Introduction
The goal of this jailbreak was to gain root on the system with the least amount of effort required. As such, it takes advantage of Webkit crash PoC code that already exists. The jailbreak was developed in around 100 hours during August and September of 2015. It was then submitted to Amazon Security and finally released in February 2016 after patch with a fix was released.

### History
There have been many exploits for kindle, but not really any named jailbreaks. So far the name just goes with the developer. Sphinx aims to be modern and therefore uses a name. The aim of sphinx is to be modern, fast and capable. Most other kindle jailbreaks are not user friendly or auto mated which sphinx aims to do.

### The aim
The point of it is to gain root privilages by exploiting a bug in the OS, at least this was the point until the hotifx extension. The hotfix extension allowed the jailbreak to remain after a OS update, making it untethered. This meant that we could restore to a jailbreakable firmware and then go back to the latest version.

Now because of that new exploits aren't being developed, so the main aim is the speed of the exploit.

### Changes in the definition
While Jailbraking started in IOS the definition of that is to gain root permissons and stable r/w access with codesign

Here on kindle we only want root permissons and codesign. Why is this? This is because the "root" directory in jailed is actually /mnt/us/ which means if we can gain root access, as there is no needed on device file manager on the kindle we do not need stable r/w access because that is fixed with root permissons. We do however need codesign so run binaries such as kterm, a kindle terminal in tools/term.

### Why bother?
Unlike IOS a kindle is not painfully limited as it fullfills it's uses. Jailbreaking however allows you to somewhat customise your setup and **add** on features which weren't meant to be there. That is the main perk of jailbreaking, adding on *extensions* to modify the OS.

### How did it get exploited?
The Kindle operating system is Linux and runs a Java based GUI that allows the user to interact with the device. Functionality is intentionally limited to eBook activities and web browsing.

The attack surfaces are self-evident. Most become quite obvious after a bit of research into previous jailbreaks and development efforts on the Kindle.

Below are some of the more obvious avenues to explore.

Document loading/parsing.
The "Experimental Browser". Runs a modified Webkit build from 2010.
Logic flaws in the Java code.
Firmware update mechanism.
Amazon management protocols.
Search bar debug commands.

E-book loading
Fertile ground for new exploits. To my knowledge, these subsystems haven't been publicly fuzzed yet. The Kindle appears to use a PDF library provided by or developed with Foxit. Most other documents are parsed by gigantic shared objects. I didn't go down this route due to the complexity of modeling various formats, but this would be an optimal route if nothing else was found. I spent a bit of time fuzzing older versions of some of the libraries the Kindle was using with afl, but no dice.

Experimental Browser
The most obvious canidate for exploitation. Old version of Webkit, plenty of PoC code already exists. Auditing a super old version of Webkit probably isn't a great use of anyone's time, but if we could get an existing CVE to work, fantastic!

Logic flaws in the Java
Many embedded systems contain debugging mechanisms that aren't fully removed for release. This usually isn't true in popular consumer devices that have been out for some time, but it's always worth looking for something simple like this as a first step.

There are hidden flags in the Java based Kindle GUI that get parsed from /mnt/us (the user storage location exposed when the Kindle is connected over USB to a computer). Worth decompiling the Java to check for any obviously unsafe or hidden debug functionality. While there is quite a bit of hidden functionality that's exposed through this method, I didn't find much after a cursory look. Did manage to find a debug dialog that called python against a user script in the /mnt/us user store. Unfortunately, accessing the dialog would require a separate vulnerability and python being installed on the Kindle. Turns out python is only on the factory provisioning debug images and wiped during sales provisioning.

### How did it get exploited part 2
There are 2 types of exploits used with sphinx. One of them is the kpw_exploit which uses E-book loading to trigger a script (more in detail later). The next exploit is a brute force exploit, this when pasted into the root directory and then triggered using webkit crash brute forces it's way through disabling security, which is why teh hotfix was needed. However the brute force exploit paired with the hotfix has become formidable and more secure.

### How to discover exploits?
Download the normal kindle firmware from amazon and go to tools/ 

If we're going to try and develop an exploit on the Kindle, it helps to have some sort of debugging functionality and/or access to the actual firmware. This is somewhat of a catch-22. If you have a Kindle that's already jailbroken you can simply SSH in to a root shell using USBNetwork. On Kindles excluding the Oasis (and possibly the new Kindle 8th Generation), a serial port can be added to the device with a bit of soldering. Either way, having access to a shell makes development easier.

For the firmware, simply download the image for your device hosted by Amazon, extract it with Kindle Tool, then mount it. Something like:
```
kindletool extract xyz.bin out
... (ssh in)
sudo mount -o loop rootfs.img root
```

Once you have extracted the firmaware you may begin studying it and fuzzing/debugging it for potential exploits
```
