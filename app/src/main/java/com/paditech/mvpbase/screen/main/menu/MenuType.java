package com.paditech.mvpbase.screen.main.menu;

import com.paditech.mvpbase.R;

/**
 * Created by ThanhNgocHoang on 11/8/2017.
 */

public class MenuType {

    public enum UserMenu {
        PROFILE(R.string.profile),
        MESSAGES(R.string.message),
        MY_PROJECT(R.string.project),
        CALENDAR(R.string.calendar),
        BECOME_PHOTOGRAPHER(R.string.register_photographer),
        HELP(R.string.help),
        ABOUT(R.string.about),
        SETTINGS(R.string.settings),
        LOGOUT(R.string.logout);

        private int text;

        UserMenu(int text) {
            this.text = text;
        }

        public int getText() {
            return text;
        }

    }

    public enum PhotographerMenu {
        PROFILE(R.string.profile),
        MESSAGES(R.string.message),
        AlBUMS(R.string.album),
        MY_PROJECT(R.string.project),
        FIND_PROJECT(R.string.find_project),
        CALENDAR(R.string.calendar),
        HELP(R.string.help),
        ABOUT(R.string.about),
        SETTINGS(R.string.settings),
        LOGOUT(R.string.logout);

        private int text;

        PhotographerMenu(int text) {
            this.text = text;
        }

        public int getText() {
            return text;
        }

    }
}
