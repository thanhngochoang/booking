package com.paditech.mvpbase.common.mvp.fragment;

import com.paditech.mvpbase.common.mvp.BasePresenter;

/**
 * Base presenter that implement base common behavior of Activity
 * <p>
 * NOTE:
 * All BasePresenter must be extend this class and init by PresenterFactory
 */
public abstract class FragmentPresenter<ViewTarget extends FragmentViewOps> extends BasePresenter<ViewTarget> implements FragmentPresenterViewOps {
    @Override
    public void onCreate() {
    }

    @Override
    public void onResume() {

    }

    @Override
    public void onPause() {

    }

    @Override
    public void onDestroy() {

    }

    @Override
    public void onResumeVisible() {

    }
}
