package com.paditech.mvpbase.common.mvp.activity;

import android.app.Activity;
import android.content.Context;
import android.os.Bundle;
import androidx.annotation.Nullable;
import androidx.fragment.app.Fragment;
import androidx.fragment.app.FragmentManager;
import androidx.fragment.app.FragmentTransaction;
import android.view.View;
import android.widget.Toast;

import com.paditech.mvpbase.R;
import com.paditech.mvpbase.common.base.BaseActivity;
import com.paditech.mvpbase.common.base.BaseDialog;
import com.paditech.mvpbase.common.dialog.MessageDialog;
import com.paditech.mvpbase.common.mvp.PresenterFactory;

/**
 * Created by ThanhNgocHoang on 6/27/2017.
 */

public abstract class MVPActivity<P extends ActivityPresenterViewOps> extends BaseActivity implements ActivityViewOps {
    private static String PRESENTER_ID;

    private MessageDialog mDialog;

    public P mPresenter;

    public P getPresenter() {
        return mPresenter;
    }

    @Override
    protected void onCreate(@Nullable Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            PRESENTER_ID = getClass().getSimpleName() + System.currentTimeMillis();
            registerPresenter();
            initPresenter();
            mPresenter.onCreate();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }

    @Override
    protected void onPause() {
        mPresenter.onPause();
        super.onPause();
    }

    @Override
    protected void onDestroy() {
        mPresenter.onDestroy();
        super.onDestroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        mPresenter.onResume();
    }

    private void registerPresenter() {
        PresenterFactory.getInstance().registerPresenter(PRESENTER_ID, onRegisterPresenter());
    }

    private void initPresenter() {
        mPresenter = (P) PresenterFactory.getInstance().createPresenter(PRESENTER_ID, this);
    }

    protected abstract Class<? extends ActivityPresenter> onRegisterPresenter();

    @Override
    public Context getActivityContext() {
        return this;
    }

    @Override
    public Context getApplicationContext() {
        return super.getApplicationContext();
    }

    @Override
    public void showProgressbar() {
        showLoadingDialog();
    }

    @Override
    public void hideProgressbar() {
        hideLoadingDialog();
    }

    @Override
    public void showAlertDialog(final String msg) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(false, msg);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showAlertDialog(boolean hasTitle, final String msg) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(true, msg);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showAlertDialog(final boolean hasTitle, final String msg, final BaseDialog.OnPositiveClickListener positiveClickListener) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(hasTitle, msg);
                mDialog.setmOnPositiveClickListener(positiveClickListener);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showAlertDialog(final String msg, final BaseDialog.OnPositiveClickListener positiveClickListener) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(false, msg);
                mDialog.setmOnPositiveClickListener(positiveClickListener);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showConfirmDialog(final String msg, final BaseDialog.OnPositiveClickListener positiveListener, final BaseDialog.OnNegativeClickListener negativeListener) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(false, msg, getString(R.string.ok), getString(R.string.cancel));
                mDialog.setmOnPositiveClickListener(positiveListener);
                mDialog.setmOnNegativeClickListener(negativeListener);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showConfirmDialog(final boolean hasTitle, final String msg, final BaseDialog.OnPositiveClickListener positiveListener, final BaseDialog.OnNegativeClickListener negativeListener) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(hasTitle, msg, getString(R.string.ok), getString(R.string.cancel));
                mDialog.setmOnPositiveClickListener(positiveListener);
                mDialog.setmOnNegativeClickListener(negativeListener);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void showConfirmDialog(final boolean hasTitle, final String msg, final String positive, final String negative, final BaseDialog.OnPositiveClickListener positiveListener,
                                  final BaseDialog.OnNegativeClickListener negativeListener) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                if (mDialog != null) mDialog.dismiss();
                mDialog = MessageDialog.newInstance(hasTitle, msg, positive, negative);
                mDialog.setmOnPositiveClickListener(positiveListener);
                mDialog.setmOnNegativeClickListener(negativeListener);
                mDialog.show(getSupportFragmentManager(), mDialog.getClass().getSimpleName());
            }
        });
    }

    @Override
    public void replaceFragment(Fragment fragment, boolean addBackStack) {
        replaceFragment(getSupportFragmentManager(), fragment, R.id.main_layout, addBackStack, R.anim.from_right, R.anim.to_left, R.anim.from_left, R.anim.to_right);

    }

    @Override
    public void replaceFragment(Fragment fragment, int layout, boolean addBackStack) {
        replaceFragment(getSupportFragmentManager(), fragment, layout, addBackStack, R.anim.from_right, R.anim.to_left, R.anim.from_left, R.anim.to_right);

    }

    @Override
    public void replaceFragment(FragmentManager manager, Fragment fragment, boolean addBackStack, int enter, int exit, int popEnter, int popExit) {
        replaceFragment(manager, fragment, R.id.main_layout, addBackStack, R.anim.from_right, R.anim.to_left, R.anim.from_left, R.anim.to_right);

    }

    @Override
    public void replaceFragment(FragmentManager manager, Fragment fragment, int layout, boolean addBackStack) {
        replaceFragment(manager, fragment, layout, addBackStack, R.anim.from_right, R.anim.to_left, R.anim.from_left, R.anim.to_right);
    }

    @Override
    public void replaceFragment(final FragmentManager manager, final Fragment fragment, final int res, final boolean addBackStack, final int enter, final int exit, final int popEnter, final int popExit) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    FragmentTransaction fragmentTransaction = manager.beginTransaction();
                    if (enter != 0 && exit != 0 && popEnter != 0 && popExit != 0)
                        fragmentTransaction.setCustomAnimations(enter, exit, popEnter, popExit);
                    if (addBackStack)
                        fragmentTransaction.addToBackStack(fragment.getClass().getSimpleName());
                    fragmentTransaction.replace(res, fragment, fragment.getClass().getSimpleName());
                    fragmentTransaction.commit();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
    }

    @Override
    public void replaceFragment(final FragmentManager manager, final Fragment fragment, final int res, final boolean addBackStack, final View shareElement, final String transitionName) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    FragmentTransaction fragmentTransaction = manager.beginTransaction();
                    if (shareElement != null)
                        fragmentTransaction.addSharedElement(shareElement, transitionName);
                    if (addBackStack)
                        fragmentTransaction.addToBackStack(fragment.getClass().getSimpleName());
                    fragmentTransaction.replace(res, fragment, fragment.getClass().getSimpleName());
                    fragmentTransaction.commit();
                } catch (Exception e) {
                    e.printStackTrace();
                }
            }
        });
    }

    @Override
    public void popBackStack() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                getSupportFragmentManager().popBackStack();
            }
        });
    }

    @Override
    public void popBackStack(final FragmentManager manager) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                manager.popBackStack();
            }
        });
    }

    @Override
    public void popBackStack(final String tag) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                getSupportFragmentManager().popBackStack(tag, FragmentManager.POP_BACK_STACK_INCLUSIVE);
            }
        });
    }

    @Override
    public void popBackStack(final FragmentManager manager, final String tag) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                manager.popBackStack(tag, FragmentManager.POP_BACK_STACK_INCLUSIVE);
            }
        });
    }

    @Override
    public void clearBackStack() {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                FragmentManager fm = getSupportFragmentManager();
                int count = fm.getBackStackEntryCount();
                for (int i = 0; i < count; ++i) {
                    fm.popBackStack();
                }
            }
        });
    }

    @Override
    public void onLoadDone() {

    }

    @Override
    public void onLoading() {

    }

    @Override
    public Activity getActivity() {
        return this;
    }

}
