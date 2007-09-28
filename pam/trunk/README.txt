
	pam - Authentication Against PAM

	Author: Evgeniy Khramtsov
	Home page: http://www.ejabberd.im/ejabberd_auth_pam
	Bug issue: https://support.process-one.net/browse/EJAB-307


	INSTALL
	=======

This code is not yet ready to be compiled.
Until the build and install scripts are fixed, 
you can use the original patch, please refer to the bug issue page.


	CONFIGURATION
	=============

Put the following in ejabberd.cfg:

  % For authentication via PAM use the following:
  {auth_method, pam}.
  {pam_service, "pamservicename"}.

