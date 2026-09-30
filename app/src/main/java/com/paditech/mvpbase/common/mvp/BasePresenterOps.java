package com.paditech.mvpbase.common.mvp;

/**
 * This interface will contain BasePresenter operation with access permitted to View
 */
public interface BasePresenterOps {
    void onCreate();
    void onDestroy();
    void onRelease();
}
