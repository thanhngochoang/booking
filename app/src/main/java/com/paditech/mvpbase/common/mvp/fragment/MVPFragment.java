package com.paditech.mvpbase.common.mvp.fragment;

import android.content.Context;
import android.os.Bundle;
import android.support.annotation.NonNull;
import android.support.annotation.Nullable;
import android.support.v4.app.Fragment;
import android.support.v4.app.FragmentManager;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.base.BaseFragment;
import com.paditech.mvpbase.common.mvp.PresenterFactory;
import com.paditech.mvpbase.common.mvp.activity.MVPActivity;

/**
 * Use this class to apply MVP into your Activity
 * <p/>
 * This class build base on BaseActivity.
 * <p/>
 * How to use:
 * 1.Create your PresenterOps extend FragmentPresenterViewOps.
 * 2.Create your BasePresenter extend ActivityPresenter that implement your PresenterOps.
 * 3.Put your PresenterOps into Generic type on top of class.
 * 4.Put BasePresenter class type on onRegisterPresenter() method.
 * 5.Create your RequiredViewOps and implement if necessary
 * 6.Now you can access your BasePresenter through mPresenter variable to control your View.
 */
public abstract class MVPFragment<P extends FragmentPresenterViewOps> extends BaseFragment implements FragmentViewOps {
    private static String P_ID;

    public P getPresenter() {
        return mPresenter;
    }

    public P mPresenter;


    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        P_ID = getClass().getSimpleName();
        registerPresenter();
        initPresenter();
        View view = super.onCreateView(inflater, container, savedInstanceState);
        mPresenter.onCreate();
        return view;
    }

    protected abstract Class<? extends FragmentPresenter> onRegisterPresenter();

    protected void refreshPresenter() {
        mPresenter.onRelease();
        initPresenter();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (mPresenter != null)
            mPresenter.onDestroy();

    }

    @Override
    public void onPause() {
        super.onPause();
        if (mPresenter != null)
            mPresenter.onPause();
    }

    @Override
    public void onHiddenChanged(boolean hidden) {
        super.onHiddenChanged(hidden);
        if (hidden) {
            mPresenter.onResumeVisible();
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        if (mPresenter != null)
            mPresenter.onResume();
    }

    @Override
    public Context getActivityContext() {
        return getActivity();
    }

    @Override
    public Context getApplicationContext() {
        return getActivity().getApplicationContext();
    }

    private void initPresenter() {
        mPresenter = (P) PresenterFactory.getInstance().createPresenter(P_ID, this);
    }

    private void registerPresenter() {
        PresenterFactory.getInstance().registerPresenter(this.getClass().getSimpleName(), onRegisterPresenter());
    }

    @Override
    public void showProgressbar() {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showProgressbar();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void hideProgressbar() {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.hideProgressbar();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showAlertDialog(boolean hasTitle, String msg) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showAlertDialog(hasTitle, msg);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showAlertDialog(boolean hasTitle, String msg, BaseDialog.OnPositiveClickListener cancelListener) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showAlertDialog(hasTitle, msg, cancelListener);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showAlertDialog(String msg) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showAlertDialog(msg);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showAlertDialog(String msg, BaseDialog.OnPositiveClickListener positiveListener) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showAlertDialog(msg, positiveListener);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showConfirmDialog(boolean hasTitle, String msg, String positive, String negative, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showConfirmDialog(hasTitle, msg, positive, negative, positiveListener, negativeListener);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showConfirmDialog(String msg, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showConfirmDialog(msg, positiveListener, negativeListener);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void showConfirmDialog(boolean hasTitle, String msg, BaseDialog.OnPositiveClickListener positiveListener, BaseDialog.OnNegativeClickListener negativeListener) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.showConfirmDialog(hasTitle, msg, positiveListener, negativeListener);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void replaceFragment(Fragment fragment, boolean addBackStack) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.replaceFragment(fragment, addBackStack);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void replaceFragment(Fragment fragment, int layout, boolean addBackStack) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.replaceFragment(fragment, layout, addBackStack);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void replaceFragment(FragmentManager manager, Fragment fragment, boolean addBackStack, int enter, int exit, int popEnter, int popExit) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.replaceFragment(manager, fragment, addBackStack, enter, exit, popEnter, popExit);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void replaceFragment(FragmentManager manager, Fragment fragment, int layout, boolean addBackStack) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.replaceFragment(manager, fragment, layout, addBackStack);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void popBackStack() {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.popBackStack();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void popBackStack(FragmentManager manager) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.popBackStack(manager);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void popBackStack(String tag) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.popBackStack(tag);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void popBackStack(FragmentManager manager, String tag) {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.popBackStack(manager, tag);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    public void clearBackStack() {
        try {
            MVPActivity mvpActivity = (MVPActivity) getActivity();
            mvpActivity.clearBackStack();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public boolean isFullScreen() {
        return false;
    }

    @Override
    public void onLoadDone() {

    }

    @Override
    public void onLoading() {

    }

    @Override
    protected boolean hasSearch() {
        return true;
    }
}
