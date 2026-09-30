package com.paditech.mvpbase.common.view;

import android.content.Context;
import android.util.AttributeSet;
import android.widget.ProgressBar;

/**
 * Created by Administrator on 09/03/2017.
 */

public class ValueProgressBar extends ProgressBar {
    public ValueProgressBar(Context context) {
        super(context);
    }

    public ValueProgressBar(Context context, AttributeSet attrs) {
        super(context, attrs);
    }

    public ValueProgressBar(Context context, AttributeSet attrs, int defStyleAttr) {
        super(context, attrs, defStyleAttr);
    }

    private ProgressBarListener mProgressBarListener;

    public void setmProgressBarListener(ProgressBarListener mProgressBarListener) {
        this.mProgressBarListener = mProgressBarListener;
    }

    public synchronized void setProgress(int progress) {
        if(progress >= this.getMax()) {
            if(mProgressBarListener != null && this.getMax() > 0)
                mProgressBarListener.onFilledBar();
        }
        super.setProgress(progress);
    }

    public interface ProgressBarListener {
        void onFilledBar();
    }
}
