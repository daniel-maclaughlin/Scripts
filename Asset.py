#!/usr/bin/python
import os

int = 1
while(int == 1):
	Asset1 = raw_input("Please input the Asset Tag Number \n")
	Asset2 = raw_input("Please confim the Asset Tag Number \n")
	

	if (Asset1 == Asset2): int = 2
	
	else:
		print 'Asset tags do not match'

command = 'sudo /usr/sbin/jamf recon -assetTag %s' %(Asset1)
os.system(command)