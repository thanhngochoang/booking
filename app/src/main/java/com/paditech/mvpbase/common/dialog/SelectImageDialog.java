package com.paditech.mvpbase.common.dialog;

import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.design.widget.BottomSheetDialogFragment;
import android.support.v4.app.FragmentManager;
import android.support.v4.app.FragmentTransaction;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.Window;


import com.paditech.mvpbase.R;

import butterknife.BindView;
import butterknife.ButterKnife;
import butterknife.OnClick;

/**
 * Visunite
 * <p>
 * Created by Paditech on 3/10/2017.
 * Copyright (c) 2017 Paditech. All rights reserved.
 */

public class SelectImageDialog extends BottomSheetDialogFragment {

    @BindView(R.id.main_layout)
    View mMainLayout;

    private SelectImageDialogListenner mSelectImageDialogListenner;

    public static SelectImageDialog newInstance() {
        return new SelectImageDialog();
    }

    public void setSelectImageDialogListenner(SelectImageDialogListenner selectImageDialogListenner) {
        this.mSelectImageDialogListenner = selectImageDialogListenner;
    }

    @Nullable
    @Override
    public View onCreateView(LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        try {
            getDialog().getWindow().requestFeature(Window.FEATURE_NO_TITLE);
            getDialog().getWindow().setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));


        } catch (Exception e) {
            e.printStackTrace();
        }
        View view = inflater.inflate(R.layout.dialog_pick_image, container, false);
        ButterKnife.bind(this, view);
        return view;
    }

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

    @OnClick(R.id.btn_pick_image)
    protected void pickImage() {
        dismiss();
        if (mSelectImageDialogListenner != null) {
            mSelectImageDialogListenner.pickImage();
        }
    }

    @OnClick(R.id.btn_take_photo)
    protected void takePhoto() {
        dismiss();
        if (mSelectImageDialogListenner != null) {
            mSelectImageDialogListenner.takePhoto();
        }
    }

    @OnClick(R.id.btn_cancel)
    public void onCancel() {
        dismiss();
    }

    public interface SelectImageDialogListenner {
        void pickImage();

        void takePhoto();
    }

    @Override
    public void dismiss() {

    }
}
