package com.paditech.mvpbase.common.utils;

import android.view.View;
import android.view.animation.AccelerateDecelerateInterpolator;
import android.view.animation.Animation;
import android.view.animation.Transformation;

/**
 * Created by ThanhNgocHoang on 11/22/2017.
 */

public class AnimUtils {
    private static final int DURATION_EXPAND = 500;

    public static void expand(final View view, final int height) {
        Animation animation = new Animation() {
            @Override
            protected void applyTransformation(float interpolatedTime, Transformation t) {
                super.applyTransformation(interpolatedTime, t);
                view.getLayoutParams().height = (int) (interpolatedTime * height);
                if (interpolatedTime == 1) {
                    view.getLayoutParams().height = height;
                }
                view.requestLayout();
            }
        };
        animation.setDuration(DURATION_EXPAND);
        animation.setInterpolator(new AccelerateDecelerateInterpolator());
        view.startAnimation(animation);
    }

    public static void collapse(final View view, final int height) {
        Animation animation = new Animation() {
            @Override
            protected void applyTransformation(float interpolatedTime, Transformation t) {
                super.applyTransformation(interpolatedTime, t);
                view.getLayoutParams().height = (int) ((1 - interpolatedTime) * height);
                if (interpolatedTime == 1) {
                    view.getLayoutParams().height = 0;
                }
                view.requestLayout();
            }
        };
        animation.setDuration(DURATION_EXPAND);
        animation.setInterpolator(new AccelerateDecelerateInterpolator());
        view.startAnimation(animation);
    }
}
