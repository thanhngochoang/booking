package com.paditech.mvpbase.common.base;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.paditech.mvpbase.common.utils.CommonUtil;
import com.paditech.mvpbase.screen.main.MainActivity;

import java.lang.ref.WeakReference;

import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 6/26/2017.
 */

public abstract class BaseFragment extends Fragment {
    protected View mRootView;
    private WeakReference<Activity> mWeakRef;

    @Override
    public void onAttach(Context context) {
        super.onAttach(context);
        mWeakRef = new WeakReference<Activity>((Activity) context);
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        /*try {
            if (mRootView == null) {
                mRootView = inflater.inflate(getContentView(), container, false);
                ButterKnife.bind(this, mRootView);
                initView(mRootView);
            } else {
                ViewGroup parent = (ViewGroup) mRootView.getParent();
                if (parent != null) {
                    parent.removeView(mRootView);
                }
            }
            setupView();
            return mRootView;
        } catch (Exception e) {
            e.printStackTrace();
        }
        return super.onCreateView(inflater, container, savedInstanceState);*/
        mRootView = inflater.inflate(getContentView(), container, false);
        ButterKnife.bind(this, mRootView);
        CommonUtil.dismissSoftKeyboard(mRootView, getActivity());
        initView(mRootView);
        setupView();
        return mRootView;
    }

    private void setupView() {
        try {
            MainActivity mainActivity = (MainActivity) getActivity();
            if (getTitle() != null)
                mainActivity.setupTitleHeader(getTitle());
            mainActivity.setSearchIcon(hasSearch());
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    protected abstract int getContentView();

    protected abstract void initView(View view);

    protected abstract String getTitle();

    protected abstract boolean hasSearch();

    public void runOnUiThread(Runnable runnable) {
        if (getActivity() != null) {
            getActivity().runOnUiThread(runnable);
        }
    }

    public WeakReference<Activity> getmWeakRef() {
        return mWeakRef;
    }

    public Activity getActivityReference() {
        return mWeakRef != null ? mWeakRef.get() : null;
    }

    public void showToast(String message) {
        try {
            BaseActivity baseActivity = (BaseActivity) getActivity();
            baseActivity.showToast(message);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    public void showError(String message) {
        try {
            BaseActivity baseActivity = (BaseActivity) getActivity();
            baseActivity.showError(message);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
