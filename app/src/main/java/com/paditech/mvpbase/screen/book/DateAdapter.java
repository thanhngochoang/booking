package com.paditech.mvpbase.screen.book;

import android.graphics.Color;
import android.graphics.Typeface;
import androidx.recyclerview.widget.RecyclerView;
import android.util.TypedValue;
import android.view.View;
import android.view.ViewGroup;
import android.widget.FrameLayout;
import android.widget.TextView;

import com.paditech.mvpbase.R;

import java.util.Calendar;
import java.util.Date;

/**
 * Created by ThanhNgocHoang on 12/20/2017.
 */

public class DateAdapter extends RecyclerView.Adapter<RecyclerView.ViewHolder> {

    private Calendar mCurrentDate;

    public DateAdapter(Date date) {
        this.mCurrentDate = Calendar.getInstance();
        this.mCurrentDate.setTime(date);
        notifyDataSetChanged();
    }

    @Override
    public RecyclerView.ViewHolder onCreateViewHolder(ViewGroup parent, int viewType) {
        TextView textView = new TextView(parent.getContext());
        textView.setTextSize(TypedValue.COMPLEX_UNIT_SP, parent.getContext().getResources().getDimensionPixelSize(R.dimen.text_size_default));
        textView.setTextColor(Color.WHITE);
        textView.setTypeface(Typeface.DEFAULT_BOLD);
        FrameLayout.LayoutParams params = new FrameLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        params.setMargins(30, 10, 30, 0);
        textView.setLayoutParams(params);
        return new TextHolder(textView);
    }

    @Override
    public void onBindViewHolder(RecyclerView.ViewHolder holder, int position) {
        TextView textView = (TextView) holder.itemView;
        textView.setText(String.valueOf(position));
        if (position == getItemCount() / 2) {
            textView.setText(String.valueOf(mCurrentDate.get(Calendar.DAY_OF_MONTH)));
        } else {
            Calendar next = Calendar.getInstance();
            next.setTime(mCurrentDate.getTime());
            next.add(Calendar.DAY_OF_MONTH, position - (getItemCount() / 2));
            textView.setText(String.valueOf(next.get(Calendar.DAY_OF_MONTH)));
        }
    }

    @Override
    public int getItemCount() {
        return 1000;
    }

    private class TextHolder extends RecyclerView.ViewHolder {

        public TextHolder(View itemView) {
            super(itemView);
        }
    }
}
