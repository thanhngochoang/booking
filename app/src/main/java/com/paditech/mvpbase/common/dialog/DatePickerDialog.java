package com.paditech.mvpbase.common.dialog;

import android.app.Dialog;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.fragment.app.DialogFragment;
import androidx.fragment.app.FragmentManager;
import android.widget.DatePicker;

import java.util.Calendar;
import java.util.Date;

/**
 * Created by Administrator on 16/02/2017.
 */

public class DatePickerDialog extends DialogFragment implements android.app.DatePickerDialog.OnDateSetListener {
    public OnDateTimePickerListener mOnDateTimePickerListener;

    public void setmOnDateTimePickerListener(OnDateTimePickerListener mOnDateTimePickerListener) {
        this.mOnDateTimePickerListener = mOnDateTimePickerListener;
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        // Use the current date as the default date in the picker
        final Calendar c = Calendar.getInstance();
        int year = c.get(Calendar.YEAR);
        int month = c.get(Calendar.MONTH);
        int day = c.get(Calendar.DAY_OF_MONTH);
        android.app.DatePickerDialog datePickerDialog = new android.app.DatePickerDialog(getActivity(), this, year, month, day);
        datePickerDialog.getDatePicker().setMinDate(c.getTimeInMillis());
        // Create a new instance of DatePickerDialog and return it
        return datePickerDialog;
    }

    @Override
    public void onDateSet(DatePicker view, int year, int month, int dayOfMonth) {
        dismiss();
        Calendar calendar = Calendar.getInstance();
        calendar.set(year, month, dayOfMonth);
        mOnDateTimePickerListener.onSelectedDate(calendar.getTime());
    }

    public interface OnDateTimePickerListener {
        void onSelectedDate(Date date);
    }

    public static void show(FragmentManager fragmentManager, OnDateTimePickerListener listener) {
        DatePickerDialog datePickerDialog = new DatePickerDialog();
        datePickerDialog.setmOnDateTimePickerListener(listener);
        datePickerDialog.show(fragmentManager, datePickerDialog.getClass().getSimpleName());
    }
}
