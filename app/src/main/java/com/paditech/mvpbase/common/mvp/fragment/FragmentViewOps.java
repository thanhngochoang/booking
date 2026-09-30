package com.paditech.mvpbase.common.mvp.fragment;


import android.content.Context;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;

import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.mvp.BaseViewOps;

/**
 * This class contain all common behavior for Activity in this App
 */
public interface FragmentViewOps extends BaseViewOps {
    /**
     * @return context of View
     */
    Context getActivityContext();

    /**
     * @return context of Application
     */
    Context getApplicationContext();

    void showProgressbar();

    void hideProgressbar();

    void showAlertDialog(String msg);

    void showAlertDialog(boolean hasTitle, String msg);

    void showAlertDialog(boolean hasTitle, String msg, BaseDialog.OnPositiveClickListener cancelListener);

    void showAlertDialog(String msg, BaseDialog.OnPositiveClickListener cancelListener);

    void showConfirmDialog(boolean hasTitle, String msg, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener);

    void showConfirmDialog(String msg, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener);

    void showConfirmDialog(boolean hasTitle, String msg, String positive, String negative, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener);

    void replaceFragment(Fragment fragment, int layout, boolean addBackStack);

    void replaceFragment(Fragment fragment, boolean addBackStack);

    void replaceFragment(FragmentManager manager, Fragment fragment, int layout, boolean addBackStack);

    void replaceFragment(FragmentManager manager, Fragment fragment, boolean addBackStack, int enter, int exit, int popEnter, int popExit);

    void popBackStack(FragmentManager manager);

    void popBackStack();

    void popBackStack(FragmentManager manager, String tag);

    void popBackStack(String tag);

    void clearBackStack();

    void onLoading();

    void onLoadDone();

    void showError(String message);
    void showToast(String message);
}

