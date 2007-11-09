%%%----------------------------------------------------------------------
%%% File    : ejabberd_http.hrl
%%% Author  : Alexey Shchepin <alexey@sevcom.net>
%%% Purpose :
%%% Created :  4 Mar 2004 by Alexey Shchepin <alexey@sevcom.net>
%%% Id      : $Id: ejabberd_http.hrl 799 2007-06-27 11:05:14Z jsautret $
%%%----------------------------------------------------------------------

-record(request, {method,
		  path,
		  q = [],
		  us,
		  auth,
		  lang = "",
		  data = "",
		  ip
		 }).
