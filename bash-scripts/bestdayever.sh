#!/bin/bash

name=$1
compliment=$2


user=$(whoami)
date=$(date)
whereami=$(pwd)

echo "Good Morning $name"
sleep 1
echo "You're looking good today $name!!"
sleep 1
echo "You have the best $compliment I've ever seen $name!!"
sleep 2

echo "you are currently logged in as $user and you are in the directo $whereami. Also today is $date"
