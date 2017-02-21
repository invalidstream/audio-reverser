# audio-reverser

Demo project from [Forward Swift](http://forwardswift.com) and [CocoaConf](http://cocoaconf.com) to decompress an audio file (MP3, AAC, etc) to LPCM, reverse the samples in another LPCM file, and allow forward/backward playback. Fun for use with "back-masked" messages in old rock songs ("Revolution No. 9", "Fire On High", etc.)

Point of the demo is to illustrate calling into Core Audio / Audio Toolbox from Swift and when it makes sense to write entire functions in C rather than convert Core Audio calls one-by-one to Swift.

![screen shot 2017-02-20 at 10 53 28 am](https://cloud.githubusercontent.com/assets/305140/23132447/9d9d0e94-f75b-11e6-8e59-8fe9f08f4cce.png)
