package com.paditech.mvpbase.common.dialog;

import android.app.Dialog;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.fragment.app.DialogFragment;
import androidx.fragment.app.FragmentManager;
import android.widget.TimePicker;

import java.util.Calendar;

/**
 * Created by ThanhNgocHoang on 12/26/2017.
 */

public class TimePickerDialog extends DialogFragment implements android.app.TimePickerDialog.OnTimeSetListener {

    public OnTimePickerListener mOnTimePickerListener;

    public void setmOnTimePickerListener(OnTimePickerListener mOnTimePickerListener) {
        this.mOnTimePickerListener = mOnTimePickerListener;
    }

    @Override
    public void onTimeSet(TimePicker view, int hourOfDay, int minute) {
        if (mOnTimePickerListener != null) mOnTimePickerListener.onSelectedTime(hourOfDay, minute);
    }

    @NonNull
    @Override
    public Dialog onCreateDialog(Bundle savedInstanceState) {
        Calendar calendar = Calendar.getInstance();
        return new android.app.TimePickerDialog(getContext(), 0, this,
                calendar.get(Calendar.HOUR_OF_DAY), Calendar.MINUTE, true);
    }

    public interface OnTimePickerListener {
        void onSelectedTime(int hour, int minute);
    }

    public static void show(FragmentManager fragmentManager, OnTimePickerListener onTimePickerListener) {
        TimePickerDialog timePickerDialog = new TimePickerDialog();
        timePickerDialog.mOnTimePickerListener = onTimePickerListener;
        timePickerDialog.show(fragmentManager, timePickerDialog.getClass().getSimpleName());
    }
}
