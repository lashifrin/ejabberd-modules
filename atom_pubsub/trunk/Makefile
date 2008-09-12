#Change /opt/lib/erlang/ in the two lines below to wherever your erlang installation is.

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

