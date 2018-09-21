#!/usr/bin/env bash

if [ -z "$(git status --porcelain)" ]; then
	echo "Pulling updates"
	git pull

	echo "OK!"
else
	echo "Commiting local changes"
	git add --all
	git commit -m 'Update'

	echo "Pulling updates"
	git pull

	echo "Pushing updates"
	git push

	echo "OK!"
fi
