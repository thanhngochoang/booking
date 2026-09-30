package com.paditech.mvpbase.common.base;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.graphics.Color;
import android.os.Bundle;
import android.support.annotation.Nullable;
import android.support.design.widget.Snackbar;
import android.support.v7.app.AppCompatActivity;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.dialog.LoadingDialog;
import com.paditech.mvpbase.common.dialog.ToastPopup;
import com.paditech.mvpbase.common.listener.OnReloadListener;
import com.paditech.mvpbase.common.utils.CommonUtil;

import butterknife.ButterKnife;

/**
 * Created by ThanhNgocHoang on 6/26/2017.
 */

public abstract class BaseActivity extends AppCompatActivity {
    private static final String CONNECT_ACTION = "android.net.conn.CONNECTIVITY_CHANGE";

    private LoadingDialog mLoadingDialog;
    private Snackbar mSnackbarNoConnect;

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(getContentView());
        overridePendingTransition(R.anim.from_right, R.anim.to_left);
        ButterKnife.bind(this);
        mLoadingDialog = new LoadingDialog();
        setupSnackBar();
        mPopupWindow = new ToastPopup(this);
        initView();
    }

    protected abstract int getContentView();

    protected abstract void initView();

    @Override
    public void finish() {
        super.finish();
        overridePendingTransition(R.anim.from_left, R.anim.to_right);
    }

    public void setupSnackBar() {
        try {
            View view = getWindow().getDecorView().findViewById(android.R.id.content);
            if (view != null) {
                mSnackbarNoConnect = Snackbar.make(view, getString(R.string.mess_no_connect), Snackbar.LENGTH_INDEFINITE);
                registerReceiver(mConnectReceiver, new IntentFilter(CONNECT_ACTION));
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private BroadcastReceiver mConnectReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent.getAction().equals(CONNECT_ACTION)) {
                if (!CommonUtil.hasConnected(context)) {
                    if (mSnackbarNoConnect != null) mSnackbarNoConnect.show();
                } else {
                    if (mSnackbarNoConnect != null) mSnackbarNoConnect.dismiss();
                }
            }
        }
    };

    @Override
    protected void onDestroy() {
        try {
            unregisterReceiver(mConnectReceiver);
        } catch (Exception ignored) {
        }
        super.onDestroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (mSnackbarNoConnect != null && !CommonUtil.hasConnected(this)) mSnackbarNoConnect.show();
    }

    public void showLoadingDialog() {
        try {
            if (mLoadingDialog != null) {
                mLoadingDialog.dismiss();
                mLoadingDialog.show(getSupportFragmentManager(), mLoadingDialog.getClass().getSimpleName());
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

    }

    public void hideLoadingDialog() {
        try {
            if (mLoadingDialog != null) {
                mLoadingDialog.dismiss();
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    private ToastPopup mPopupWindow;

    public void showToast(final String message) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if(mPopupWindow != null && mPopupWindow.isShowing()) mPopupWindow.dismiss();
                View view = getWindow().getDecorView().findViewById(android.R.id.content);
                if (view != null)
                    mPopupWindow.show(view, message, ToastPopup.ToastType.ALERT);
            }
        });

    }

    public void showError(final String message) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if(mPopupWindow != null && mPopupWindow.isShowing()) mPopupWindow.dismiss();
                View view = getWindow().getDecorView().findViewById(android.R.id.content);
                if (view != null)
                    mPopupWindow.show(view, message, ToastPopup.ToastType.ERROR);
            }
        });

    }
}
