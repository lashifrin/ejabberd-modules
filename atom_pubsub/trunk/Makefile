#Change /opt/lib/erlang/ in the two lines below to wherever your erlang installation is.
ERLANG_CFLAGS = -I/opt/lib/erlang/lib/erl_interface-3.5.5.3/include -I/opt/lib/erlang/usr/include
ERLANG_LIBS = -L/opt/lib/erlang/lib/erl_interface-3.5.5.3/lib -lerl_interface -lei

EFLAGS = -I . -pz .. -pa . 

SOURCES = $(wildcard *.erl)
#Change that to match your ejabberd beam dir
OUTDIR = .


BEAMS = $(addprefix $(OUTDIR)/,$(SOURCES:.erl=.beam))

all: $(BEAMS)

$(OUTDIR)/%.beam:	%.erl
	erlc -W $(EFLAGS) -o $(OUTDIR) $<

clean:
	rm -f $(BEAMS)

