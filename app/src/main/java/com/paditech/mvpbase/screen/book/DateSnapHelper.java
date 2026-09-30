package com.paditech.mvpbase.screen.book;

import android.content.Context;
import android.support.v7.widget.LinearLayoutManager;
import android.support.v7.widget.RecyclerView;
import android.util.AttributeSet;
import android.util.Log;
import android.view.View;

/**
 * Created by ThanhNgocHoang on 12/20/2017.
 */

public class DateSnapHelper extends LinearLayoutManager {

    private boolean scrollable = true;

    public void setScrollable(boolean scrollable) {
        this.scrollable = scrollable;
    }

    public DateSnapHelper(Context context) {
        super(context);
    }

    public DateSnapHelper(Context context, int orientation, boolean reverseLayout) {
        super(context, orientation, reverseLayout);
    }

    public DateSnapHelper(Context context, AttributeSet attrs, int defStyleAttr, int defStyleRes) {
        super(context, attrs, defStyleAttr, defStyleRes);
    }


    @Override
    public boolean canScrollHorizontally() {
        return scrollable;
    }

    @Override
    public int scrollHorizontallyBy(int dx, RecyclerView.Recycler recycler, RecyclerView.State state) {
        updateChildrenAlpha();
        return super.scrollHorizontallyBy(dx, recycler, state);
    }

    @Override
    public void onLayoutChildren(RecyclerView.Recycler recycler, RecyclerView.State state) {
        super.onLayoutChildren(recycler, state);
        Log.e("onLayoutChildren", "onLayoutChildren");
        updateChildrenAlpha();
    }

    public void updateChildrenAlpha() {
        for (int i = 0; i < getChildCount(); i++) {
            View child = getChildAt(i);
            float maxDist = getWidth() * 0.8f;
            float right = getDecoratedRight(child);
            float left = getDecoratedLeft(child);
            float childCenter = left + (right - left) / 2; // Get item center position
            float center = getWidth() / 2; // Get RecyclerView's center position
            float alpha = Math.abs((Math.abs(center - childCenter) - maxDist)) / maxDist;
            if (i == getChildCount() / 2) {
                child.setAlpha(1);
                child.setScaleX(1);
                child.setScaleY(1);
            } else {
                child.setAlpha(alpha);
                child.setScaleX(alpha);
                child.setScaleY(alpha);
            }
            // Map between 0f and 1f the abs value of the distance
            // between the center of item and center of the RecyclerView
            // and set it as alpha
        }
    }

}
