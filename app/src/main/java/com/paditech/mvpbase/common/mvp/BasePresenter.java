package com.paditech.mvpbase.common.mvp;

import java.lang.ref.WeakReference;

/**
 * Abstract BasePresenter that implement base PresenterOps and RequiredPresenterOps
 */
public abstract class BasePresenter<ViewTarget extends BaseViewOps> implements BasePresenterOps, PresenterViewOps {
    private WeakReference<ViewTarget> targetWeakReference;
    protected boolean isRelease;

    public void takeView(BaseViewOps viewTarget) {
        targetWeakReference = new WeakReference<>((ViewTarget) viewTarget);
    }

    protected ViewTarget getView() {
        return targetWeakReference.get();
    }

    @Override
    public void onDestroy() {
        targetWeakReference.clear();
        targetWeakReference = null;
        isRelease = true;
    }

    @Override
    public void onRelease() {
        isRelease = true;
        targetWeakReference.clear();
    }
}
