# this assumes minisat's already been built in ../minisat

CXX ?= g++
CXXFLAGS ?= -O3

all: zc2hs

zc2hs: 
	ln -fs ../minisat/Proof.o
	ln -fs ../minisat/File.o
	ln -fs ../minisat/File.h
	ln -fs ../minisat/Proof.h
	ln -fs ../minisat/Global.h
	ln -fs ../minisat/Sort.h
	ln -fs ../minisat/SolverTypes.h
	$(CXX) $(CXXFLAGS) Proof.o File.o zc2hs.cpp -o zc2hs

clean:
	rm -f zc2hs *.h *.o
