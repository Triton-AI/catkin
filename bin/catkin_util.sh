TMPDIR=$PWD/.tmp/$$
# /bin/echo "$0 will be working in temporary dir $TMPDIR"

initializeANSI()
{
  esc=""

  blackf="${esc}[30m";   redf="${esc}[31m";    greenf="${esc}[32m"
  yellowf="${esc}[33m"   bluef="${esc}[34m";   purplef="${esc}[35m"
  cyanf="${esc}[36m";    whitef="${esc}[37m"

  blackb="${esc}[40m";   redb="${esc}[41m";    greenb="${esc}[42m"
  yellowb="${esc}[43m"   blueb="${esc}[44m";   purpleb="${esc}[45m"
  cyanb="${esc}[46m";    whiteb="${esc}[47m"

  boldon="${esc}[1m";    boldoff="${esc}[22m"
  italicson="${esc}[3m"; italicsoff="${esc}[23m"
  ulon="${esc}[4m";      uloff="${esc}[24m"
  invon="${esc}[7m";     invoff="${esc}[27m"

  reset="${esc}[0m"

}

initializeANSI

maybe_continue () {
    DEFAULT=$1
    shift
    PROMPT=$*
    # assert_nonempty "$DEFAULT"
    status $PROMPT
    /bin/echo -n "${boldon}Continue "

    if [ "$DEFAULT" = 'y' -o "$DEFAULT" = 'y' ] ; then
        /bin/echo "${yellowf}[Y/n]?${reset}"
    else
        /bin/echo "${yellowf}[y/N]?${reset}"
    fi
    read IN
    if [ -z "$IN" ] ; then
        IN=$DEFAULT
    fi
    if [ $IN = 'N' -o $IN = 'n' ] ; then
        bailout "Exiting."
    fi
}

get_version_component ()
{
    REGEX='/.*\((\d+)\.(\d+)\.(\d+)\-(\d+)(\w+)\)/'
    NUM=$1
    REV=$2
    VALUE=$(perl -e "\"$REV\" =~ $REGEX  && print \$$NUM")
}

bailout ()  {
    /bin/echo "${redf}${boldon}$*${reset}"
    exit 1
}

checking ()  {
    /bin/echo "${yellowf}$*${reset}"
}

status () {
    /bin/echo "${cyanf}$*${reset}"
}

okay ()  {
    /bin/echo "${greenf}$*${reset}"
}

read_stack_yaml ()
{
    FILENAME=$1
    if [ ! -e $FILENAME ] ; then
        bailout "Hm, attempt to read file $FILENAME which does not exist."
    fi

    TXT=$(cat $FILENAME)

    VERSION_FULL=$(/bin/echo $TXT | perl -ne '/Version:\s+([^\s]+)/ && print $1')
    get_version_component 1 $VERSION_FULL
    VERSION_MAJOR=$VALUE
    get_version_component 2 $VERSION_FULL
    VERSION_MINOR=$VALUE
    get_version_component 3 $VERSION_FULL
    VERSION_PATCH=$VALUE
}

prompt_continue()
{
    /bin/echo $*
    status "Press enter to continue, ^C to abort..."
    read MEH
    if [ "$MEH" = 'q' -o "$MEH" = 'Q' ] ; then
        bailout "exiting"
    fi
}

assert_is_remote_git_repo ()
{
    REPO=$1
    checking "Verifying that $REPO is a git repo...${reset}"
    LSREMOT=$(git ls-remote --heads $REPO)
    RCODE=$?
    if [ $RCODE -ne 0 ]; then
        bailout "$REPO doesn't appear to be a git repo!"
    else
        okay "Yup, with $(/bin/echo $LSREMOT | wc -l) heads."
    fi
}

assert_is_gbp_repo ()
{
    REPO=$1
    NDEBTAGS=$(git ls-remote --tags $REPO debian/\* | wc -l)
    checking "Verifying that repo is a git-buildpackage repo"
    if [ $NDEBTAGS -eq 0 ] ; then
        bailout "Repo $REPO doesn't seem to have any tags with 'debian' in them"
    else
        okay "Yeah, there are $NDEBTAGS debian tags in there"
    fi
    NUPSTREAM=$(git ls-remote --tags $REPO upstream/\* | wc -l)
    checking "Verifying that repo is a git-buildpackage repo"
    if [ $NUPSTREAM -eq 0 ] ; then
        bailout "Repo $REPO doesn't seem to have any tags with 'upstream' in them"
    else
        okay "Yeah, there are $NUPSTREAM upstream branches in there"
    fi
}

assert_is_not_gbp_repo ()
{
    REPO=$1
    LSREMOT=$(git ls-remote --heads $REPO upstream\* | wc -l)
    checking "Verifying that ${boldon}$REPO${boldoff} is ${boldon}not${boldoff} a git-buildpackage repo"
    if [ $LSREMOT -ne 0 ] ; then
        /bin/echo "${redf}Error: $REPO appears to have an 'upstream' branch, but shouldn't, I'm treating it as being the upstream itself."
        git ls-remote --heads $REPO upstream\*
        bailout "Looks like this repo is git-buildpackage, but should not be"
    else
        okay "Yup, no upstream branches."
    fi
}

assert_nonempty ()
{
    if [ -z "$1" ] ; then
        bailout "assertion, failed variable unset"
    fi
}

get_latest_gbp_version ()
{
    REPO=$1
    pushd $REPO
    LASTTAG=$(git for-each-ref --sort='*authordate' --format='%(refname:short)' refs/tags/debian | tail -1)
    /bin/echo "Last tag in gbp repo is ${boldon}$LASTTAG${reset}"
    LASTREV=$(git show $LASTTAG:debian/changelog | head -1)
    assert_nonempty $LASTREV
    /bin/echo "Disassembling ${boldon}$LASTREV${reset}"
    get_version_component 1 "$LASTREV"
    GBP_MAJOR=$VALUE
    assert_nonempty $GBP_MAJOR
    get_version_component 2 "$LASTREV"
    GBP_MINOR=$VALUE
    get_version_component 3 "$LASTREV"
    GBP_PATCH=$VALUE
    get_version_component 4 "$LASTREV"
    GBP_PACKAGE=$VALUE

    /bin/echo "Got version components ${boldon}$GBP_MAJOR $GBP_MINOR $GBP_PATCH - $GBP_PACKAGE${reset}"
    popd
}

to_github_uri ()
{
    SHORTY=$1
    /bin/echo "Having a look at ${!SHORTY}"

    if [[ "${!SHORTY}" =~ ^git@github.com:wg-debs ]] ; then
        status "URI ${boldon}${!SHORTY}${boldoff} appears to already point to github."
        return 0
    fi
    TO_GITHUB_TRANSFORM=$(git config catkin.gbproot)
    ARG=${!SHORTY}
    NEW=$(/bin/echo ${!TO_GITHUB_TRANSFORM})
    status "Redirecting '${!SHORTY}' to ${boldon}$NEW${boldoff}"
    eval $SHORTY=$NEW
}

check_git_version ()
{
    set -e
    status "Checking git compatibility.  If things bail out your git is too old"
    status "Version 1.7.4.1 is known to work"
    mkdir -p $TMPDIR/gittest
    pushd $TMPDIR/gittest
    git init
    V=compat_test_if_this_fails_your_git_is_too_old
    touch $V
    git add $V
    git commit -m $V
    git checkout --orphan $V
    set +e
    /bin/echo "Your ${boldon}$(git --version)${boldoff} appears to work."
    popd
    rm -rf $TMPDIR/gittest
}


# check_git_version

