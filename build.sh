#!/usr/bin/env bash

if [ ! -d build ]; then
	mkdir build
fi	

if [ -d build/DailyStandupGenerator.app ]; then
	rm -rf build/DailyStandupGenerator.app
fi

osacompile -o build/DailyStandupGenerator.app -x DailyStandup.scpt && \
cp -R DailyStandupGenerator.app/bin build/DailyStandupGenerator.app/
