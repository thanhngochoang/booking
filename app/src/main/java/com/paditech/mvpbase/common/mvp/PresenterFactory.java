/*
 * Copyright (c) 2016 CANON INC.
 * All rights reserved.
 */

package com.paditech.mvpbase.common.mvp;

import java.util.HashMap;

/**
 * This class is a singleton that build on factory pattern, will be used to create BasePresenter link with it's View whole app.
 * BasePresenter will be register once on baseActivity by the first time
 */
public class PresenterFactory {
    private static final String TAG = "Create Presenter";
    //Map that contain BasePresenter with ID
    private HashMap<String, Class<?>> mRegisterPresenters = new HashMap<>();

    //Single instance
    private static PresenterFactory instance;

    private PresenterFactory() {
    }

    public static PresenterFactory getInstance() {
        if (instance == null) {
            synchronized (PresenterFactory.class) {
                instance = new PresenterFactory();
            }
        }
        return instance;
    }

    /**
     * Register a BasePresenter to init later
     *
     * @param presenterId : id to define presenter will be created
     * @param clazz       type of presenter will be create math with id
     * @return current instance to use for
     */

    public PresenterFactory registerPresenter(String presenterId, Class<?> clazz) {
        if (!mRegisterPresenters.containsKey(presenterId)) {
            mRegisterPresenters.put(presenterId, clazz);
        }
        return this;
    }

    /**
     * create BasePresenter and return to use
     *
     * @param presenterId : id that registered
     * @param baseView:   base view that reference to the presenter
     * @return presenter that hold a View to handle user interact
     */
    public synchronized BasePresenterOps createPresenter(String presenterId, BaseViewOps baseView) {
        Class<?> clazz = mRegisterPresenters.get(presenterId);
        BasePresenter object = null;
        try {
            object = (BasePresenter) clazz.newInstance();
            object.takeView(baseView);
        } catch (InstantiationException | IllegalAccessException | NullPointerException e) {
            //Logger.e(TAG, e.getMessage(), e);
        }

        return object;
    }
}
