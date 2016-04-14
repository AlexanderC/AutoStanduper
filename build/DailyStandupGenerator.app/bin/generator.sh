#!/usr/bin/env bash

GITHUB_ACCESS_TOKEN="$1"
GITHUB_ORG="$2"
GIT_USER="$3"

if [ -z "$GITHUB_ACCESS_TOKEN" ]; then
  echo "Missing GitHub access token!"
  exit 1
fi

if [ -z "$GITHUB_ORG" ]; then
  echo "Missing GitHub user/organization!"
  exit 1
fi

if [ -z "$GIT_USER" ]; then
  GIT_USER=$(git config user.name)
fi

if [ -z "$GIT_USER" ]; then
  echo "Missing Your GitHub username!"
  exit 1
fi

LAST_WORKING_DATE_ISO() {
  case "$(date +%a)" in 
    Mon)
      echo `date -v-4d -u +%Y-%m-%d`"T00:00:00Z";
      ;;
    *)
      echo `date -v-1d -u +%Y-%m-%d`"T00:00:00Z";
      ;;
  esac
}

LAST_WORKING_DATE() {
  case "$(date +%a)" in 
    Mon)
      echo `date -v-4d +%Y-%m-%d`;
      ;;
    *)
      echo `date -v-1d +%Y-%m-%d`;
      ;;
  esac
}

TODAY_DATE() {
  echo `date +%Y-%m-%d`;
}

LAST_WORKING_DAY_NAME() {
  case "$(date +%a)" in 
    Mon)
      echo 'Friday';
      ;;
    *)
      echo 'Yesterday';
      ;;
  esac
}

LIST_PROJECTS() {
  local api_url="https://api.github.com/search/repositories?access_token=$GITHUB_ACCESS_TOKEN&q=user:$GITHUB_ORG"

  curl -s "$api_url" -H "Accept: application/vnd.github.VERSION.text+json" | python -c "import json,sys;obj=json.load(sys.stdin); map(lambda x: sys.stdout.write('%s' % (x['name']) + '\n'), obj['items'])"
}

REPO_BRANCHES() {
  local repo="$1"
  local api_url="https://api.github.com/repos/${repo}/branches?access_token=$GITHUB_ACCESS_TOKEN"

  curl -s "$api_url" -H "Accept: application/vnd.github.VERSION.text+json" | python -c "import json,sys;arr=json.load(sys.stdin); map(lambda x: sys.stdout.write('%s' % (x['name']) + '\n'), arr)"
}

IS_REPO_ACTIVE() {
  local repo="$1"
  local last_working_date=$(LAST_WORKING_DATE_ISO)
  local api_url="https://api.github.com/repos/${repo}/commits?access_token=$GITHUB_ACCESS_TOKEN&author=$GIT_USER&since=${last_working_date}&sha="

  for branch in $(REPO_BRANCHES ${repo})
  do
    local output=$(curl -s "$api_url$branch" -H "Accept: application/vnd.github.VERSION.text+json" | python -c "import json,sys;arr=json.load(sys.stdin); sys.stdout.write('%s' % (len(arr)))")

    if [ "$output" != "0" ]; then
      echo "1"
      break
    fi
  done
}

LIST_ACTIVE_PROJECTS() {
  for repo_name in $(LIST_PROJECTS)
  do
    local repo="$GITHUB_ORG/${repo_name}"

    local is_active=$(IS_REPO_ACTIVE ${repo})

    if [ "$is_active" = "1" ]; then
      echo ${repo}
    fi
  done
}

TASKS() {
  local repo="$1"
  local api_url="https://api.github.com/search/issues?access_token=$GITHUB_ACCESS_TOKEN&q=type:issue+assignee:$GIT_USER+is:open+repo:$repo"

  local tasks_plain=$(curl -s "$api_url" -H "Accept: application/vnd.github.VERSION.text+json" | python -c "import json,sys;obj=json.load(sys.stdin); map(lambda x: sys.stdout.write('#%s %s {%s}' % (x['number'],x['title'], ', '.join(('%s' % (y['name'])) for y in x['labels'])) + '\n'), obj['items'])")

  if [ ! -z "$tasks_plain" ]; then
    echo "   - Project $proj"
    echo "$tasks_plain" | while read line; do echo "      - $line"; done
  fi
}

HISTORY() {
  local repo="$1"
  local last_working_date=$(LAST_WORKING_DATE_ISO)
  local api_url="https://api.github.com/repos/${repo}/commits?access_token=$GITHUB_ACCESS_TOKEN&author=$GIT_USER&since=${last_working_date}&sha="
  local result=""

  for active_branch in $(REPO_BRANCHES ${repo})
  do
    local output=$(curl -s "$api_url$active_branch" -H "Accept: application/vnd.github.VERSION.text+json" | python -c "import json,sys;arr=json.load(sys.stdin); map(lambda x: sys.stdout.write(' ' * 12 + '%s' % (('\n' + ' ' * 15).join(x['commit']['message'].split('\n'))) + '\n'), arr if isinstance(arr, list) else list())")
    
    if [ ! -z "$output" ]; then
      result="$result
         - Branch $active_branch"
      result="$result
$output"
    fi
  done

  if [ ! -z "$result" ]; then
    echo "   - Project $repo$result"
  fi
}

PROJECTS=$(LIST_ACTIVE_PROJECTS)

echo "Hi Team,"
echo ""
echo `LAST_WORKING_DAY_NAME`:
for proj in $PROJECTS
do
  HISTORY $proj
done
echo "Today:"
for proj in $PROJECTS
do
  TASKS $proj
done
