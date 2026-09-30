package com.paditech.mvpbase.screen.calendar;

import android.graphics.RectF;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.view.View;

import com.alamkanak.weekview.DateTimeInterpreter;
import com.alamkanak.weekview.MonthLoader;
import com.alamkanak.weekview.WeekView;
import com.alamkanak.weekview.WeekViewEvent;
import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.event.OnUpdateCalendarEvent;
import com.paditech.mvpbase.common.model.Booking;
import com.paditech.mvpbase.common.mvp.fragment.FragmentPresenter;
import com.paditech.mvpbase.common.mvp.fragment.MVPFragment;
import com.paditech.mvpbase.screen.book.BookFragment;

import org.greenrobot.eventbus.EventBus;
import org.greenrobot.eventbus.Subscribe;
import org.greenrobot.eventbus.ThreadMode;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Calendar;
import java.util.List;
import java.util.Locale;

import butterknife.BindView;

/**
 * Created by ThanhNgocHoang on 12/25/2017.
 */

public class CalendarFragment extends MVPFragment<CalendarContact.PresenterViewOps> implements
        CalendarContact.ViewOps, WeekView.EventClickListener, MonthLoader.MonthChangeListener,
        WeekView.EventLongPressListener {
    @BindView(R.id.weekView)
    WeekView weekView;

    private List<Booking> mListBookings = new ArrayList<>();

    @Override
    protected Class<? extends FragmentPresenter> onRegisterPresenter() {
        return CalendarPresenter.class;
    }

    @Override
    public void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        EventBus.getDefault().register(this);
    }

    @Override
    public void onDestroy() {
        EventBus.getDefault().unregister(this);
        super.onDestroy();
    }

    @Override
    protected int getContentView() {
        return R.layout.frag_calendar;
    }

    @Override
    protected void initView(View view) {
        weekView.setOnEventClickListener(this);
        weekView.setMonthChangeListener(this);
        weekView.setEventLongPressListener(this);
       /* weekView.setDateTimeInterpreter(new DateTimeInterpreter() {
            @Override
            public String interpretDate(Calendar date) {
                SimpleDateFormat weekdayNameFormat = new SimpleDateFormat("EEE", Locale.getDefault());
                String weekday = weekdayNameFormat.format(date.getTime());
                SimpleDateFormat format = new SimpleDateFormat(" M/d", Locale.getDefault());

                // All android api level do not have a standard way of getting the first letter of
                // the week day name. Hence we get the first char programmatically.
                // Details: http://stackoverflow.com/questions/16959502/get-one-letter-abbreviation-of-week-day-of-a-date-in-java#answer-16959657
                return weekday.toUpperCase() + format.format(date.getTime());
            }

            @Override
            public String interpretTime(int hour) {
                return hour > 11 ? (hour - 12) + " PM" : (hour == 0 ? "12 AM" : hour + " AM");
            }
        });
*/

    }

    @Override
    protected String getTitle() {
        return getString(R.string.calendar);
    }

    @Override
    public List<? extends WeekViewEvent> onMonthChange(int newYear, int newMonth) {
        return getPresenter().getListEvents(newYear, newMonth-1);
    }

    @Override
    public void onEventClick(WeekViewEvent event, RectF eventRect) {
        try {
            Booking booking = mListBookings.get((int) event.getId());
            if (booking != null) replaceFragment(BookFragment.newInstance(booking), true);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void onEventLongPress(WeekViewEvent event, RectF eventRect) {

    }

    @Override
    public void updateListEvents(List<Booking> bookings) {
        mListBookings = bookings;
    }

    @Subscribe(threadMode = ThreadMode.MAIN)
    public void onUpdateCalendar(OnUpdateCalendarEvent event) {
        Calendar calendar = Calendar.getInstance();
        getPresenter().getListEvents(calendar.get(Calendar.YEAR), calendar.get(Calendar.MONTH));
    }
}
