package com.paditech.mvpbase.common.mvp.activity;


import com.paditech.mvpbase.common.mvp.BasePresenter;

/**
 * Base presenter that implement base common behavior of Activity
 * <p>
 * NOTE:
 * All BasePresenter must be extend this class and init by PresenterFactory
 */
public abstract class ActivityPresenter<ViewTarget extends ActivityViewOps> extends BasePresenter<ViewTarget> implements ActivityPresenterViewOps {

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
}
