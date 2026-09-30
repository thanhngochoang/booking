package com.paditech.mvpbase.screen.calendar;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;

import com.alamkanak.weekview.WeekViewEvent;
import com.google.android.gms.tasks.OnCompleteListener;
import com.google.android.gms.tasks.Task;
import com.google.firebase.firestore.DocumentSnapshot;
import com.google.firebase.firestore.FirebaseFirestore;
import com.google.firebase.firestore.QuerySnapshot;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.firebase.FirebaseHelper;
import com.paditech.mvpbase.common.firebase.GetUserInfoListener;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.model.User;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.utils.PrefUtil;

import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;

import io.realm.Realm;
import io.realm.RealmResults;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public class CalendarPresenter extends FragmentPresenter<CalendarContact.ViewOps> implements CalendarContact.PresenterViewOps {

    @Override
    public ArrayList<WeekViewEvent> getListEvents(int year, int month) {
        try {
            final RealmResults<Booking> bookings = Realm.getDefaultInstance().where(Booking.class).findAll();
            final ArrayList<WeekViewEvent> listEvents = new ArrayList<>();
            for (final Booking booking : bookings) {
                Calendar start = Calendar.getInstance();
                start.setTime(booking.getStart_time());
                Calendar end = Calendar.getInstance();
                end.setTime(booking.getEnd_time());
                end.add(Calendar.DAY_OF_MONTH, 1);
                if (start.get(Calendar.YEAR) == year && start.get(Calendar.MONTH) == month) {
                    WeekViewEvent weekViewEvent = new WeekViewEvent(listEvents.size(), booking.getAddress_name(), "", start, end);
                    weekViewEvent.setColor(ContextCompat.getColor(getView().getActivityContext(), booking.getStatus().getColor()));
                    listEvents.add(weekViewEvent);
                }
            }
            getView().updateListEvents(bookings);
            return listEvents;
        } catch (Exception e) {
            e.printStackTrace();
            return new ArrayList<>();
        }
    }
}
