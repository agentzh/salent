.PHONY: all

all: report.html

%.html: %.pod
	podhtm.pl --css perl.css -o $@ --index $<

