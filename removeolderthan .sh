#!/bin/bash

find /Users/daniel/Desktop/screenshot1/ -mtime +30 -exec rm {} \;
find /Users/daniel/Desktop/screenshot2/ -mtime +30 -exec rm {} \;
find /Users/daniel/Desktop/screenshot3/ -mtime +30 -exec rm {} \;

exit 0
