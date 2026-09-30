package com.paditech.mvpbase.common.base;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import androidx.annotation.Nullable;
import com.google.android.material.bottomsheet.BottomSheetDialogFragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;

import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 11/15/2017.
 */

public abstract class BaseBottomDialog extends BottomSheetDialogFragment {
    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        try {
            getDialog().requestWindowFeature(Window.FEATURE_NO_TITLE);
            getDialog().getWindow().setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
            getDialog().getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));
        } catch (Exception e) {
            e.printStackTrace();
        }
        View view = inflater.inflate(getContentView(), container, false);
        ButterKnife.bind(this, view);
        initView(view);
        return view;
    }

    protected abstract int getContentView();

    protected abstract void initView(View view);

    @Override
    public void show(FragmentManager manager, String tag) {
        try {
            super.show(manager, tag);
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    @Override
    public int show(FragmentTransaction transaction, String tag) {
        try {
            return super.show(transaction, tag);
        } catch (Exception e) {
            e.printStackTrace();
        }
        return -1;
    }

    /*@Override
    public void dismiss() {
        try {
            Animation animation = AnimationUtils.loadAnimation(getContext(), R.anim.to_bottom);
            animation.setAnimationListener(new Animation.AnimationListener() {
                @Override
                public void onAnimationStart(Animation animation) {

                }

                @Override
                public void onAnimationEnd(Animation animation) {
                    try {
                        BaseBottomDialog.super.dismiss();
                    } catch (Exception e) {
                        e.printStackTrace();
                    }
                }

                @Override
                public void onAnimationRepeat(Animation animation) {

                }
            });
            if (getView() != null)
                getView().startAnimation(animation);
        } catch (Exception e){
            e.printStackTrace();
        }
    }*/
}
