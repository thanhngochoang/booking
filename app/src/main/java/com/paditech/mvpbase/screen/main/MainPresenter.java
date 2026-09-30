package com.paditech.mvpbase.screen.main;

import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.ChatRoom;
import com.paditech.mvpbase.common.mvp.activity.ActivityPresenter;

import io.realm.Realm;

import static com.paditech.mvpbase.screen.main.MainContact.*;

/**
 * Created by ThanhNgocHoang on 9/19/2017.
 */

public class MainPresenter extends ActivityPresenter<MainContact.ViewOps> implements PresenterViewOps {
    @Override
    public int getBadgeCountMess() {
        Realm realm = Realm.getDefaultInstance();
        return realm.where(ChatRoom.class).equalTo("is_read", false).findAll().size();
    }

    @Override
    public int getBadgeCountCalendar() {
        Realm realm = Realm.getDefaultInstance();
        return realm.where(Booking.class).equalTo("status", 0).findAll().size();
    }
}
