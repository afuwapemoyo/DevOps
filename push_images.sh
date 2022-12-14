#!/bin/bash

# Script to push docker images to jfrog artifactory
# Developers can build local docker images and they can run this script with single argument as ./push_images.sh java/test_app:1.0
# If no tag passed version it will push as latest tag like java/test_app:latest


pushto_jfrog()
 {
        if [ -z  ${tag_name} ]
        then
          tag_name="latest"
          echo "Pushing docker image with tag ${tag_name} to jfrog artifactory"
          docker tag ${repo_name}:${tag_name}  ${jfrog_registry}/${repo_name}:${tag_name}
          docker push ${jfrog_registry}/${repo_name}:${tag_name}
        else
          echo "Pushing docker image with tag ${tag_name} to jfrog artifactory"
          docker tag ${repo_name}:${tag_name}  ${jfrog_registry}/${repo_name}:${tag_name}
          docker push ${jfrog_registry}/${repo_name}:${tag_name}
        fi
 }

jfrog()
{
    echo "<<password>>" | docker login --username <<user_name>> --password-stdin "<<docker_registry_url>>" &> /dev/null
    repo_and_tag="$1"
    repo_name=(${repo_and_tag//:/ })
    tag_name=(`echo ${repo_and_tag}|grep ':'| cut -d: -f2`)
    jfrog_registry="<<docker_registry_url>>"
    pushto_jfrog
}
jfrog $1
