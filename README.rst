Description
===========

Small crunchyroll commandline watchlist manager.

Because keeping track of where I am in what serie is troublesome.

Documentation
=============

::

    Usage: crunchyroll -h
           crunchyroll add TITLE
           crunchyroll see TITLE
           crunchyroll remove TITLE
           crunchyroll status [[TITLE] NEW_STATUS]

    Options:
        -h, --help  Print this help and exit

    Commands:
        add         Add or search for animes by TITLE or URL
        see         See the next episode of TITLE
        remove      Remove an anime by TITLE
        status      See or set the current status of all or one animes

    Arguments:
        URL         An crunchyroll anime URL
        TITLE       Part of an anime title.
                    Case insensitive, the first title to match is taken.
        NEW_STATUS  Integer, number of the episode in the serie

License
=======

This program is under the GPLv3 License.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

Contact
=======

::

    Main developper: Cédric Picard
    Email:           cpicard@openmailbox.org
