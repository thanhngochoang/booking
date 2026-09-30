package com.paditech.mvpbase.common.view;

import android.content.Context;
import android.graphics.Canvas;
import android.graphics.PorterDuff;
import android.graphics.Rect;
import android.graphics.drawable.Drawable;
import android.graphics.drawable.GradientDrawable;
import android.support.v4.content.ContextCompat;
import android.support.v7.widget.RecyclerView;
import android.view.View;

import com.paditech.mvpbase.R;

/**
 * Created by Administrator on 03/03/2017.
 */

public class SimpleDividerItemDecoration extends RecyclerView.ItemDecoration {
    private GradientDrawable mDivider;
    private int paddingLeft, paddingRight;
    private boolean hasLastLine = true, hasFooter = false;
    private int color = 0xe9e9e9, line = 1;

    public SimpleDividerItemDecoration(Context context) {
        color = ContextCompat.getColor(context, R.color.divider);
        mDivider = (GradientDrawable) ContextCompat.getDrawable(context, R.drawable.line_divider);
        mDivider.setColor(color);
        mDivider.setColorFilter(color, PorterDuff.Mode.SRC_ATOP);
        mDivider.setSize(-1, line);
    }

    public SimpleDividerItemDecoration(Context context, int l, int r) {
        color = ContextCompat.getColor(context, R.color.divider);
        paddingLeft = l;
        paddingRight = r;
        mDivider = (GradientDrawable) ContextCompat.getDrawable(context, R.drawable.line_divider);
        mDivider.setColor(color);
        mDivider.setColorFilter(color, PorterDuff.Mode.SRC_ATOP);
        mDivider.setSize(-1, line);
    }

    public SimpleDividerItemDecoration(Context context, int color) {
        this.color = color;
        mDivider = (GradientDrawable) ContextCompat.getDrawable(context, R.drawable.line_divider);
        mDivider.setColor(color);
        mDivider.setColorFilter(color, PorterDuff.Mode.SRC_ATOP);
        mDivider.setSize(-1, line);
    }

    public SimpleDividerItemDecoration(Context context, int color, int l, int r) {
        this.color = color;
        paddingLeft = l;
        paddingRight = r;
        mDivider = (GradientDrawable) ContextCompat.getDrawable(context, R.drawable.line_divider);
        mDivider.setColor(color);
        mDivider.setColorFilter(color, PorterDuff.Mode.SRC_ATOP);
        mDivider.setSize(-1, line);
    }

    public void setHasLastLine(boolean hasLastLine) {
        this.hasLastLine = hasLastLine;
    }

    public void setHasLastLine(boolean hasLastLine, boolean hasFooter) {
        this.hasLastLine = hasLastLine;
        this.hasFooter = hasFooter;
    }

    @Override
    public void getItemOffsets(Rect outRect, View view, RecyclerView parent, RecyclerView.State state) {
        if (parent.getChildAdapterPosition(view) == parent.getChildCount() - 1) return;
        super.getItemOffsets(outRect, view, parent, state);
    }

    @Override
    public void onDrawOver(Canvas c, RecyclerView parent, RecyclerView.State state) {
        int left = parent.getPaddingLeft() + paddingLeft;
        int right = parent.getWidth() - parent.getPaddingRight() - paddingRight;

        int childCount = parent.getChildCount();
        int size;
        if (!hasLastLine) {
            if (hasFooter) size = childCount - 2;
            else size = childCount - 1;
        } else {
            if (hasFooter) size = childCount - 1;
            else size = childCount;
        }
        for (int i = 0; i < size; i++) {
            View child = parent.getChildAt(i);

            RecyclerView.LayoutParams params = (RecyclerView.LayoutParams) child.getLayoutParams();

            int top = child.getBottom() + params.bottomMargin;
            int bottom = top + mDivider.getIntrinsicHeight();

            mDivider.setBounds(left, top, right, bottom);
            mDivider.draw(c);
        }
    }
}